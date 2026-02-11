// lib/features/send/view_model/send_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

/// ViewModel for the Send screen.
///
/// **Expendable balance**: [StellarAccountService.getXlmBalance] already
/// returns the *spendable* amount (total − reserve − selling‑liabilities).
/// The VM therefore treats balances as the ceiling the user can spend and
/// does **not** subtract any reserve or trustline overhead itself.
class SendVM extends ChangeNotifier {
  SendVM({
    required StellarWalletServices service,
    required SeedKeypairVM seedVM,
  })  : _svc = service,
        _seedVM = seedVM;

  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;

  // ──────────────────────────────────────────────────────────────────────────
  // Session state
  // ──────────────────────────────────────────────────────────────────────────

  String? _accountId;
  String? get accountId => _accountId;
  String get senderAddress => _accountId ?? _senderAddr;

  bool _configured = false;
  late SendToken _token;
  late String _senderAddr;
  late double _senderBalToken;  // expendable balance (reserve already out)
  String? _prefillName;

  SendToken get token => _token;
  bool get isXlm => _token == SendToken.xlm;
  double get senderBalanceToken => _senderBalToken;
  String? get prefillName => _prefillName;

  // ──────────────────────────────────────────────────────────────────────────
  // Input
  // ──────────────────────────────────────────────────────────────────────────

  String _to = '';
  double _typedAmount = 0;
  String get to => _to;
  double get typedAmount => _typedAmount;

  // ──────────────────────────────────────────────────────────────────────────
  // Status / error
  // ──────────────────────────────────────────────────────────────────────────

  bool _loading = true;
  String? _err;
  bool get loading => _loading;
  String? get error => _err;

  // ──────────────────────────────────────────────────────────────────────────
  // Network fee estimation (Stellar base fee only)
  // ──────────────────────────────────────────────────────────────────────────

  double? _estNetworkFeeXlm;
  double? get estNetworkFeeXlm => _estNetworkFeeXlm;

  // ──────────────────────────────────────────────────────────────────────────
  // Trustline check (dest USDC only — sender handled by service)
  // ──────────────────────────────────────────────────────────────────────────

  bool _checking = false;
  bool? _destHasUsdcTL;
  bool get checking => _checking;
  bool? get destHasUsdcTL => _destHasUsdcTL;

  // ──────────────────────────────────────────────────────────────────────────
  // Streams / timers
  // ──────────────────────────────────────────────────────────────────────────

  StreamSubscription? _feeSub;
  Timer? _debounce;

  bool _disposed = false;

  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Configure
  // ──────────────────────────────────────────────────────────────────────────

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

    _accountId = _seedVM.accountId ?? senderAddress;

    _to = (prefillTo ?? '').trim();
    _typedAmount = 0;

    _destHasUsdcTL = null;
    _checking = false;

    _err = null;
    _configured = true;
    _loading = true;

    _estNetworkFeeXlm = null;

    _start();
  }

  Future<void> _start() async {
    try {
      final KeyPair kp = await _seedVM.deriveKeyPair();
      _accountId = kp.accountId;

      // Estimate network fee
      try {
        _estNetworkFeeXlm = await _svc.estimateNetworkFeeXlm(
            opCount: 1, percentile: 90);
      } catch (_) {
        _estNetworkFeeXlm = null;
      }

      _resubscribeFeeStream();

      _loading = false;
      _err = null;
      _safeNotify();
    } catch (_) {
      _loading = false;
      _err = 'No wallet found.';
      _safeNotify();
    }
  }

  void _resubscribeFeeStream() {
    _feeSub?.cancel();
    _feeSub = _svc
        .feeEstimateStream(opCount: 1, percentile: 90)
        .listen((f) {
      _estNetworkFeeXlm = f.totalXlm;
      _safeNotify();
    }, onError: (_) {});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Inputs
  // ──────────────────────────────────────────────────────────────────────────

  void setRecipient(String v) {
    _to = v.trim();
    _safeNotify();
    _debounceCheckTrustline();
  }

  void setTypedAmount(double v) {
    _typedAmount = v.clamp(0, double.infinity);
    _safeNotify();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Trustline (dest)
  // ──────────────────────────────────────────────────────────────────────────

  void _debounceCheckTrustline() {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 300), _checkTrustlineIfNeeded);
  }

  bool _looksStellar(String s) =>
      s.isNotEmpty && s.startsWith('G') && s.length == 56;

  Future<void> _checkTrustlineIfNeeded() async {
    if (!_configured) return;
    final dest = _to;

    if (!_looksStellar(dest)) {
      _destHasUsdcTL = null;
      _safeNotify();
      return;
    }
    if (isXlm) {
      _destHasUsdcTL = null;
      _safeNotify();
      return;
    }

    _checking = true;
    _destHasUsdcTL = null;
    _safeNotify();

    try {
      _destHasUsdcTL = await _svc.hasUsdcTrustline(dest);
    } catch (_) {
      _destHasUsdcTL = null;
    } finally {
      _checking = false;
      _safeNotify();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Fees refresh
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> refreshFees() async {
    _resubscribeFeeStream();
    try {
      _estNetworkFeeXlm = await _svc.estimateNetworkFeeXlm(
          opCount: 1, percentile: 90);
    } catch (_) {}
    _safeNotify();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Budget math — no reserve logic, balances are already expendable
  // ──────────────────────────────────────────────────────────────────────────

  double _floor7(double v) => (v * 1e7).floor() / 1e7;

  /// Network fee for display purposes
  double get networkFee => _estNetworkFeeXlm ?? 0;

  /// What the recipient will actually receive (same as typed amount for XLM)
  double get recipientWillReceive {
    if (_typedAmount <= 0) return 0;
    return _typedAmount;
  }

  /// Total deducted from balance (amount + network fee for XLM)
  double get totalDeductFromBalance {
    if (_typedAmount <= 0) return 0;
    if (isXlm) {
      return _floor7(_typedAmount + networkFee);
    } else {
      // USDC: only USDC amount is deducted, network fee comes from XLM balance
      return _typedAmount;
    }
  }

  /// Remaining expendable balance after this transaction
  double get remainingExpendable {
    return (_senderBalToken - totalDeductFromBalance).clamp(0, double.infinity);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Validation
  // ──────────────────────────────────────────────────────────────────────────

  String? get blockingReason {
    if (!_configured) return 'Not configured';
    if (!_looksStellar(_to)) return 'Enter a valid Stellar address (G…)';
    if (_typedAmount <= 0) return 'Enter amount';

    if (isXlm) {
      final totalNeeded = totalDeductFromBalance;
      if (totalNeeded > _senderBalToken + 1e-9) {
        return 'Amount + network fee exceeds XLM balance';
      }
      return null;
    } else {
      if (_typedAmount > _senderBalToken + 1e-9) {
        return 'Amount exceeds USDC balance';
      }
      if (_destHasUsdcTL == false) {
        return 'Recipient has no USDC trustline';
      }
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Recipient helpers
  // ──────────────────────────────────────────────────────────────────────────

  void pickRecipient(String address, {String? displayName}) {
    final addr = address.trim();
    if (addr.isEmpty) return;
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) _prefillName = name;
    _to = addr;
    _safeNotify();
    _debounceCheckTrustline();
  }

  void clearPrefillName() {
    _prefillName = null;
    _safeNotify();
  }

  String? get recipientLabel => _prefillName;

  // ──────────────────────────────────────────────────────────────────────────
  // Submit
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> submit({String? memo}) async {
    final reason = blockingReason;
    if (reason != null) throw StateError(reason);

    await refreshFees();

    final KeyPair keyPair = await _seedVM.deriveKeyPair();

    if (isXlm) {
      // Verify we have enough for amount + network fee
      final totalNeeded = totalDeductFromBalance;
      if (totalNeeded > _senderBalToken + 1e-9) {
        throw StateError('Amount + network fee exceeds XLM balance');
      }

      final txid = await _svc.sendXlm(
        keyPair: keyPair,
        destination: _to,
        amount: _typedAmount,
        memoText: memo,
      );
      return txid;
    } else {
      final txid = await _svc.sendUsdc(
        keyPair: keyPair,
        destination: _to,
        usdcAmount: _typedAmount,
        memoText: memo,
      );
      return txid;
    }
  }
}