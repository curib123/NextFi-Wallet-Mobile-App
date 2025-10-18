import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/features/send/model/send_token.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

class SendVM extends ChangeNotifier {
  SendVM({
    required StellarWalletServices service,
    required SeedKeypairVM seedVM,
  })  : _svc = service,
        _seedVM = seedVM;

  // DI
  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;

  // Wallet/session
  String? _accountId;
  String? get accountId => _accountId;
  String get senderAddress => _accountId ?? _senderAddr;

  bool _configured = false;
  late SendToken _token;
  late String _senderAddr;
  late double _senderBalToken; // balance of token being sent (XLM or USDC)
  double? _senderBalXlm;       // for USDC sends (fee coverage)
  String? _prefillName;

  SendToken get token => _token;
  bool get isXlm => _token == SendToken.xlm;
  double get senderBalanceToken => _senderBalToken;
  double? get senderBalanceXlm => _senderBalXlm;
  String? get prefillName => _prefillName;

  // NEW: does SENDER have a USDC trustline?
  bool _selfHasUsdcTL = false;
  bool get selfHasUsdcTrustline => _selfHasUsdcTL;

  // Input
  String _to = '';
  double _typedAmount = 0;
  String get to => _to;
  double get typedAmount => _typedAmount;

  // Status / error
  bool _loading = true;
  String? _err;
  bool get loading => _loading;
  String? get error => _err;

  // Fees
  double? _txFeeXlm;         // app fee (dynamic XLM)
  double? _estNetworkFeeXlm; // estimated network fee (XLM)
  double? get txFeeXlm => _txFeeXlm;
  double? get estNetworkFeeXlm => _estNetworkFeeXlm;

  int get _opCount => ((_txFeeXlm ?? 0) > 0) ? 2 : 1;

  // Trustline check (DEST USDC)
  bool _checking = false;
  bool? _destHasUsdcTL;
  bool get checking => _checking;
  bool? get destHasUsdcTL => _destHasUsdcTL;

  // Streams/timers
  StreamSubscription? _feeSub;
  Timer? _debounce;

  // lifecycle
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

  // Configure a fresh session
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
    _senderBalXlm = null;
    _prefillName = prefillName;

    _accountId = _seedVM.accountId ?? senderAddress;

    _to = (prefillTo ?? '').trim();
    _typedAmount = 0;

    _destHasUsdcTL = null;
    _checking = false;

    _err = null;
    _configured = true;
    _loading = true;

    _txFeeXlm = null;
    _estNetworkFeeXlm = null;

    _selfHasUsdcTL = false;

    _start();
  }

  Future<void> _start() async {
    try {
      final KeyPair kp = await _seedVM.deriveKeyPair();
      _accountId = kp.accountId;

      // Sender balances / trustlines
      if (!isXlm) {
        try {
          _senderBalXlm = await _svc.getXlmBalance(_accountId!);
        } catch (_) {
          _senderBalXlm = null;
        }
      }
      try {
        _selfHasUsdcTL = await _svc.hasUsdcTrustline(_accountId!);
      } catch (_) {
        _selfHasUsdcTL = false;
      }

      // Fees
      _txFeeXlm = await _svc.getCurrentFeeXlm();
      try {
        _estNetworkFeeXlm =
        await _svc.estimateNetworkFeeXlm(opCount: _opCount, percentile: 90);
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
        .feeEstimateStream(opCount: _opCount, percentile: 90)
        .listen((f) {
      _estNetworkFeeXlm = f.totalXlm;
      _safeNotify();
    }, onError: (_) {});
  }

  // Inputs
  void setRecipient(String v) {
    _to = v.trim();
    _safeNotify();
    _debounceCheckTrustline();
  }

  void setTypedAmount(double v) {
    _typedAmount = v.clamp(0, double.infinity);
    _safeNotify();
  }

  // Trustline (dest)
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

  // Fees refresh
  Future<void> refreshFees() async {
    _txFeeXlm = await _svc.getCurrentFeeXlm();
    _resubscribeFeeStream();
    try {
      _estNetworkFeeXlm =
      await _svc.estimateNetworkFeeXlm(opCount: _opCount, percentile: 90);
    } catch (_) {}
    if (!isXlm && _accountId != null) {
      try {
        _senderBalXlm = await _svc.getXlmBalance(_accountId!);
      } catch (_) {}
    }
    try {
      if (_accountId != null) {
        _selfHasUsdcTL = await _svc.hasUsdcTrustline(_accountId!);
      }
    } catch (_) {}
    _safeNotify();
  }

  // Budget math
  double _floor7(double v) => (v * 1e7).floor() / 1e7;

  double get recipientWillReceiveXlmFromBudget {
    if (!isXlm) return 0;
    final fee = _txFeeXlm ?? 0;
    final net = _estNetworkFeeXlm ?? 0;
    final budget = _typedAmount;
    if (budget <= 0) return 0;

    final amountParam = (budget - net);
    if (amountParam <= fee + 1e-7) return 0;

    final recv = _floor7(amountParam - fee);
    return recv > 0 ? recv : 0;
  }

  double get totalDeductXlmIfXlmSend =>
      isXlm ? (_typedAmount > 0 ? _typedAmount : 0) : 0;

  double get needsXlmForFeesIfUsdcSend =>
      isXlm ? 0 : _floor7((_txFeeXlm ?? 0) + (_estNetworkFeeXlm ?? 0));

  // Validation
  String? get blockingReason {
    if (!_configured) return 'Not configured';
    if (!_looksStellar(_to)) return 'Enter a valid Stellar address (G...)';
    if (_typedAmount <= 0) return 'Enter amount';

    if (isXlm) {
      if (_typedAmount > _senderBalToken + 1e-9) {
        return 'Amount exceeds XLM balance';
      }
      if (recipientWillReceiveXlmFromBudget <= 0) {
        return 'Amount too small after fees';
      }
      return null;
    } else {
      if (_typedAmount > _senderBalToken + 1e-9) {
        return 'Amount exceeds USDC balance';
      }
      if (_destHasUsdcTL == false) {
        return 'Recipient has no USDC trustline';
      }
      final xlmNeed = needsXlmForFeesIfUsdcSend;
      final xlmBal = _senderBalXlm ?? 0;
      if (xlmBal + 1e-9 < xlmNeed) {
        return 'Not enough XLM to cover fees (${xlmNeed.toStringAsFixed(7)} XLM required)';
      }
      return null;
    }
  }

  // Recipient helpers
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

  // Submit
  Future<String> submit({String? memo}) async {
    final reason = blockingReason;
    if (reason != null) throw StateError(reason);

    await refreshFees();

    final KeyPair keyPair = await _seedVM.deriveKeyPair();

    if (isXlm) {
      final net = _estNetworkFeeXlm ?? 0;
      final fee = _txFeeXlm ?? 0;

      final amountParam = _typedAmount - net;
      if (amountParam <= fee + 1e-7) {
        throw StateError('Amount too small after fees.');
      }

      final txids = await _svc.sendXlmWithFee(
        keyPair: keyPair,
        destination: _to,
        amount: _floor7(amountParam),
        memoText: memo,
      );
      return txids.first;
    } else {
      try {
        _senderBalXlm = await _svc.getXlmBalance(keyPair.accountId);
      } catch (_) {}
      final xlmNeed = needsXlmForFeesIfUsdcSend;
      if ((_senderBalXlm ?? 0) + 1e-9 < xlmNeed) {
        throw StateError(
            'Not enough XLM to cover fees (${xlmNeed.toStringAsFixed(7)} XLM required).');
      }

      final txids = await _svc.sendUsdcWithFee(
        keyPair: keyPair,
        destination: _to,
        usdcAmount: _typedAmount,
        memoText: memo,
      );
      return txids.first;
    }
  }
}
