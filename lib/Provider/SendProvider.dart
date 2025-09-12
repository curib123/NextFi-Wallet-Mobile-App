// lib/Provider/SendProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/Services/seed_storage.dart';

enum SendToken { xlm, usdc }

class SendProvider extends ChangeNotifier {
  SendProvider({StellarWalletService? service})
      : _svc = service ?? StellarWalletService();

  // ── Service / wallet ───────────────────────────────────────────────────────
  final StellarWalletService _svc;
  Wallet? _wallet;
  KeyPair? _kp;
  String? _accountId; // G...

  String? get accountId => _accountId;
  bool get ready => _kp != null && _accountId != null;

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
    // kick wallet load & fee bootstrap
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

  // ── Boot wallet & prefetch fees (now stream-driven) ───────────────────────
  Future<void> _start() async {
    _loading = true;
    _err = null;
    notifyListeners();

    try {
      // Wallet
      final m = await SeedStorage.getSeed();
      if (m == null || m.isEmpty) {
        _loading = false;
        _err = 'No wallet found.';
        notifyListeners();
        return;
      }
      _wallet = await StellarWalletService.walletFromMnemonic(m);
      _kp = await StellarWalletService.getKeyPair(_wallet!, index: 0);
      _accountId = _kp!.accountId;

      // Fixed TX fee (from secure vault)
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
      _err = 'Failed to load wallet.';
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
    if (!ready) return;
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
    // Fixed fee might change if vault rotates; re-read it.
    _txFeeXlm = await _svc.getCurrentFeeXlm();
    // If opCount changed due to fee toggling, resubscribe stream.
    _resubscribeFeeStream();
    // Also grab a fresh point estimate immediately.
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
  // If XLM and user types total budget T, we send:
  //   amountParam = max(T − estNetwork, txFee)
  //   recipient    = amountParam − txFee
  // So total wallet deduction ≈ T (subject to fee variance).
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
    if (!ready) return 'Wallet not loaded';
    if (!_looksStellar(_to)) return 'Enter a valid Stellar address (G...)';
    if (_typedAmount <= 0) return 'Enter amount';
    if (isXlm) {
      // Check balance: need at least budget
      if (_typedAmount > _senderBalToken + 1e-9) return 'Amount exceeds XLM balance';
      if (recipientWillReceiveXlmFromBudget <= 0) {
        return 'Amount too small after fees';
      }
      return null;
    } else {
      // USDC: amount must not exceed USDC balance and sender must have XLM fees
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

    final seed = _extractSeed(_kp!);

    if (isXlm) {
      final net = _estNetworkFeeXlm ?? 0;
      final fee = _txFeeXlm ?? 0;

      // amount param = budget minus estimated network fee (never below fee)
      final amountParam = (_typedAmount - net);
      if (amountParam <= fee + 1e-7) {
        throw StateError('Amount too small after fees.');
      }
      return await _svc
          .sendXlmWithFee(
        secretSeed: seed,
        destination: _to,
        amount: _floor7(amountParam),
        memoText: memo,
      )
          .then((h) => h.first);
    } else {
      // USDC: send typed amount; XLM fees are charged separately
      return await _svc
          .sendUsdcWithFee(
        secretSeed: seed,
        destination: _to,
        usdcAmount: _typedAmount,
        memoText: memo,
      )
          .then((h) => h.first);
    }
  }

  String _extractSeed(KeyPair kp) {
    final dynamic ss = kp.secretSeed;
    if (ss is String) return ss;
    if (ss is Iterable<int>) return String.fromCharCodes(ss);
    throw Exception('Unsupported secretSeed type: ${ss.runtimeType}');
  }
}

// Small helper to silence unawaited futures.
void unawaited(Future<void> f) {}
