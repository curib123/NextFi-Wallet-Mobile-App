import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/Services/seed_storage.dart';

enum SendToken { xlm, usdc }

class SendProvider extends ChangeNotifier {
  SendProvider({
    required StellarWalletService service,
    Future<String?> Function()? getActiveSeed,
  })  : _svc = service,
        _getActiveSeed = getActiveSeed ?? SeedStorage.getActiveSeed;

  // ── Service / secrets access (DI) ─────────────────────────────────────────
  final StellarWalletService _svc;
  final Future<String?> Function() _getActiveSeed;

  // We DO NOT hold wallet or keypair in memory for the session. Safer.
  String? _accountId; // G... (display/source of truth for sender)
  String? get accountId => _accountId;

  bool get ready => _configured && (_accountId?.isNotEmpty ?? false);

  // ── “Screen session” config (set when opening SendScreen) ─────────────────
  bool _configured = false;
  late SendToken _token;            // xlm or usdc (for this send session)
  late String  _senderAddr;         // display/use if wallet isn’t ready yet
  late double  _senderBalToken;     // balance in selected token
  String? _prefillName;

  SendToken get token => _token;
  bool get isXlm => _token == SendToken.xlm;
  double get senderBalanceToken => _senderBalToken;

  // ── User input ────────────────────────────────────────────────────────────
  String _to = '';
  double _typedAmount = 0;          // what the user typed in the field
  String get to => _to;
  double get typedAmount => _typedAmount;

  void configure({
    required SendToken token,
    required String senderAddress,
    required double senderBalanceToken,
    String? prefillTo,
    String? prefillName,
  }) {
    _token = token;
    _senderAddr = senderAddress;
    _senderBalToken = senderBalanceToken;
    _prefillName = prefillName;

    // The sender address for UI. We also try to confirm an active seed exists.
    _accountId = senderAddress;

    // reset session
    _to = (prefillTo ?? '').trim();
    _typedAmount = 0;
    _destHasUsdcTL = null;
    _checking = false;
    _err = null;
    _configured = true;
    _estNetworkFeeXlm = null;
    _txFeeXlm = null;

    notifyListeners();
    // kick fee bootstrap (no wallet derivation here)
    unawaited(_start());
  }

  // ── Derived: address/name mix ─────────────────────────────────────────────
  String get senderAddress => _accountId ?? _senderAddr;
  String? get prefillName => _prefillName;

  // ── Status / errors ───────────────────────────────────────────────────────
  bool _loading = true;
  String? _err;
  bool get loading => _loading;
  String? get error => _err;

  // ── Fee model (fixed tx fee + estimated network fee) ──────────────────────
  double? _txFeeXlm;           // fixed transaction fee (from vault)
  double? _estNetworkFeeXlm;   // estimated network fee (updated via stream)
  double? get txFeeXlm => _txFeeXlm;
  double? get estNetworkFeeXlm => _estNetworkFeeXlm;

  // Trustline checks (for USDC dest)
  bool _checking = false;
  bool? _destHasUsdcTL;
  bool get checking => _checking;
  bool? get destHasUsdcTL => _destHasUsdcTL;

  // Subscriptions / timers
  StreamSubscription? _feeSub;
  Timer? _debounce;

  // ── Boot prefetch fees (no mnemonic/keypair kept) ─────────────────────────
  Future<void> _start() async {
    _loading = true;
    _err = null;
    notifyListeners();

    try {
      // Ensure there is an active seed (but do NOT keep it)
      final m = await _getActiveSeed();
      if (m == null || m.isEmpty) {
        _loading = false;
        _err = 'No wallet found.';
        notifyListeners();
        return;
      }

      // Fixed TX fee (from secure vault/service)
      _txFeeXlm = await _svc.getCurrentFeeXlm();

      // Initial network fee snapshot (while stream warms up)
      try {
        _estNetworkFeeXlm = await _svc.estimateNetworkFeeXlm(
          opCount: _opCount,
          percentile: 90,
        );
      } catch (_) {
        _estNetworkFeeXlm = null;
      }

      // Subscribe to network fee updates on each ledger close
      _resubscribeFeeStream();

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _err = 'Failed to initialize sending.';
      notifyListeners();
    }
  }

  void _resubscribeFeeStream() {
    _feeSub?.cancel();
    _feeSub = _svc
        .feeEstimateStream(opCount: _opCount, percentile: 90)
        .listen((f) {
      _estNetworkFeeXlm = f.totalXlm;
      notifyListeners();
    }, onError: (_) {
      // keep last known estimate on errors
    });
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // ── User interactions ─────────────────────────────────────────────────────
  void setRecipient(String v) {
    _to = v.trim();
    notifyListeners();
    _debounceCheckTrustline();
  }

  void setTypedAmount(double v) {
    _typedAmount = v.clamp(0, double.infinity);
    notifyListeners();
    // opCount does not depend on amount, so fee stream remains valid
  }

  // ── Trustline guard (USDC) ────────────────────────────────────────────────
  void _debounceCheckTrustline() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _checkTrustlineIfNeeded);
  }

  bool _looksStellar(String s) => s.isNotEmpty && s.startsWith('G') && s.length == 56;

  Future<void> _checkTrustlineIfNeeded() async {
    if (!_configured) return;
    final dest = _to;
    if (!_looksStellar(dest)) {
      _destHasUsdcTL = null;
      notifyListeners();
      return;
    }
    if (isXlm) {
      _destHasUsdcTL = null; // not needed for XLM
      notifyListeners();
      return;
    }
    _checking = true;
    _destHasUsdcTL = null;
    notifyListeners();
    try {
      _destHasUsdcTL = await _svc.hasUsdcTrustline(dest);
    } catch (_) {
      _destHasUsdcTL = null; // unknown
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  // ── Fee logic ─────────────────────────────────────────────────────────────
  int get _opCount {
    // 1 op for token payment; +1 op for XLM fee if fee > 0
    final hasTxFee = (_txFeeXlm ?? 0) > 0;
    return hasTxFee ? 2 : 1;
  }

  /// Refresh fees on demand (e.g., before submit).
  Future<void> refreshFees() async {
    _txFeeXlm = await _svc.getCurrentFeeXlm();
    _resubscribeFeeStream();
    try {
      _estNetworkFeeXlm = await _svc.estimateNetworkFeeXlm(
        opCount: _opCount,
        percentile: 90,
      );
    } catch (_) {
      // keep last
    }
    notifyListeners();
  }

  // ── Budget split (core requirement) ───────────────────────────────────────
  double _floor7(double v) => (v * 1e7).floor() / 1e7;

  double get recipientWillReceiveXlmFromBudget {
    if (!isXlm) return 0;
    final fee = _txFeeXlm ?? 0;
    final net = _estNetworkFeeXlm ?? 0;
    final budget = _typedAmount;
    if (budget <= 0) return 0;
    final sendParam = (budget - net).clamp(0, double.infinity);
    if (sendParam <= fee + 1e-7) return 0;
    final recv = _floor7(sendParam - fee);
    return recv > 0 ? recv : 0;
  }

  double get totalDeductXlmIfXlmSend {
    if (!isXlm) return 0;
    final budget = _typedAmount;
    return budget > 0 ? budget : 0;
  }

  double get needsXlmForFeesIfUsdcSend {
    if (isXlm) return 0;
    final fee = _txFeeXlm ?? 0;
    final net = _estNetworkFeeXlm ?? 0;
    return _floor7(fee + net);
  }

  // ── Guards / validation ───────────────────────────────────────────────────
  String? get blockingReason {
    if (!_configured) return 'Not configured';
    if (!_looksStellar(_to)) return 'Enter a valid Stellar address (G...)';
    if (_typedAmount <= 0) return 'Enter amount';
    if (isXlm) {
      if (_typedAmount > _senderBalToken + 1e-9) return 'Amount exceeds XLM balance';
      if (recipientWillReceiveXlmFromBudget <= 0) {
        return 'Amount too small after fees';
      }
      return null;
    } else {
      if (_typedAmount > _senderBalToken + 1e-9) return 'Amount exceeds USDC balance';
      if (_destHasUsdcTL == false) return 'Recipient has no USDC trustline';
      return null;
    }
  }

  // ── Execute ───────────────────────────────────────────────────────────────
  Future<String> submit({String? memo}) async {
    final reason = blockingReason;
    if (reason != null) throw StateError(reason);

    // Keep fees fresh just before submit
    await refreshFees();

    // Get the active seed JUST-IN-TIME; do not persist it in memory.
    final seed = await _getActiveSeed();
    if (seed == null || seed.isEmpty) {
      throw StateError('No wallet found.');
    }

    try {
      if (isXlm) {
        final net = _estNetworkFeeXlm ?? 0;
        final fee = _txFeeXlm ?? 0;

        // amount param = budget minus estimated network fee (never below fee)
        final amountParam = (_typedAmount - net);
        if (amountParam <= fee + 1e-7) {
          throw StateError('Amount too small after fees.');
        }
        final txids = await _svc.sendXlmWithFee(
          secretSeed: seed,
          destination: _to,
          amount: _floor7(amountParam),
          memoText: memo,
        );
        return txids.first;
      } else {
        final txids = await _svc.sendUsdcWithFee(
          secretSeed: seed,
          destination: _to,
          usdcAmount: _typedAmount,
          memoText: memo,
        );
        return txids.first;
      }
    } finally {
      // Best-effort: clear local reference ASAP
      // (Dart doesn't let us securely zero memory, but we can drop refs.)
      // ignore: unused_local_variable
      // // seed = '';  // (can’t reassign because it's final)
    }
  }
}

// Small helper to silence unawaited futures.
void unawaited(Future<void> f) {}
