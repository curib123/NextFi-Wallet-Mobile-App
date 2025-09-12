// lib/features/send/viewmodel/send_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/Services/seed_storage.dart';

import '../model/send_token.dart';

class SendVM extends ChangeNotifier {
  SendVM({
    required StellarWalletService service,
    Future<String?> Function()? getActiveSeed,
  })  : _svc = service,
        _getActiveSeed = getActiveSeed ?? SeedStorage.getActiveSeed;

  // DI
  final StellarWalletService _svc;
  final Future<String?> Function() _getActiveSeed;

  // Wallet/display
  String? _accountId;
  String? get accountId => _accountId;
  String get senderAddress => _accountId ?? _senderAddr;

  // Session config
  bool _configured = false;
  late SendToken _token;
  late String  _senderAddr;
  late double  _senderBalToken;
  String? _prefillName;

  SendToken get token => _token;
  bool get isXlm => _token == SendToken.xlm;
  double get senderBalanceToken => _senderBalToken;
  String? get prefillName => _prefillName;

  // UI input
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
  double? _txFeeXlm;
  double? _estNetworkFeeXlm;
  double? get txFeeXlm => _txFeeXlm;
  double? get estNetworkFeeXlm => _estNetworkFeeXlm;

  // Trustline checks
  bool _checking = false;
  bool? _destHasUsdcTL;
  bool get checking => _checking;
  bool? get destHasUsdcTL => _destHasUsdcTL;

  // Streams/timers
  StreamSubscription? _feeSub;
  Timer? _debounce;

  // Configure a fresh “send session”
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

    _accountId = senderAddress;

    _to = (prefillTo ?? '').trim();
    _typedAmount = 0;
    _destHasUsdcTL = null;
    _checking = false;
    _err = null;
    _configured = true;
    _loading = true;
    _txFeeXlm = null;
    _estNetworkFeeXlm = null;

    notifyListeners();
    _start();
  }

  // Boot: fees + stream
  Future<void> _start() async {
    try {
      final m = await _getActiveSeed();
      if (m == null || m.isEmpty) {
        _loading = false;
        _err = 'No wallet found.';
        notifyListeners();
        return;
      }

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
      notifyListeners();
    } catch (_) {
      _loading = false;
      _err = 'Failed to initialize sending.';
      notifyListeners();
    }
  }

  void _resubscribeFeeStream() {
    _feeSub?.cancel();
    _feeSub = _svc.feeEstimateStream(opCount: _opCount, percentile: 90).listen(
          (f) {
        _estNetworkFeeXlm = f.totalXlm;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // User interactions
  void setRecipient(String v) {
    _to = v.trim();
    notifyListeners();
    _debounceCheckTrustline();
  }

  void setTypedAmount(double v) {
    _typedAmount = v.clamp(0, double.infinity);
    notifyListeners();
  }

  // Trustline
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
      _destHasUsdcTL = null;
      notifyListeners();
      return;
    }
    _checking = true;
    _destHasUsdcTL = null;
    notifyListeners();
    try {
      _destHasUsdcTL = await _svc.hasUsdcTrustline(dest);
    } catch (_) {
      _destHasUsdcTL = null;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  // Fees
  int get _opCount {
    final hasTxFee = (_txFeeXlm ?? 0) > 0;
    return hasTxFee ? 2 : 1;
  }

  Future<void> refreshFees() async {
    _txFeeXlm = await _svc.getCurrentFeeXlm();
    _resubscribeFeeStream();
    try {
      _estNetworkFeeXlm =
      await _svc.estimateNetworkFeeXlm(opCount: _opCount, percentile: 90);
    } catch (_) {}
    notifyListeners();
  }

  // Budget math
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

  double get totalDeductXlmIfXlmSend => isXlm ? (_typedAmount > 0 ? _typedAmount : 0) : 0;

  double get needsXlmForFeesIfUsdcSend =>
      isXlm ? 0 : _floor7((_txFeeXlm ?? 0) + (_estNetworkFeeXlm ?? 0));

  // Validation
  String? get blockingReason {
    if (!_configured) return 'Not configured';
    if (!_looksStellar(_to)) return 'Enter a valid Stellar address (G...)';
    if (_typedAmount <= 0) return 'Enter amount';
    if (isXlm) {
      if (_typedAmount > _senderBalToken + 1e-9) return 'Amount exceeds XLM balance';
      if (recipientWillReceiveXlmFromBudget <= 0) return 'Amount too small after fees';
      return null;
    } else {
      if (_typedAmount > _senderBalToken + 1e-9) return 'Amount exceeds USDC balance';
      if (_destHasUsdcTL == false) return 'Recipient has no USDC trustline';
      return null;
    }
  }

  // Submit
  Future<String> submit({String? memo}) async {
    final reason = blockingReason;
    if (reason != null) throw StateError(reason);

    await refreshFees();

    final seed = await _getActiveSeed();
    if (seed == null || seed.isEmpty) {
      throw StateError('No wallet found.');
    }

    if (isXlm) {
      final net = _estNetworkFeeXlm ?? 0;
      final fee = _txFeeXlm ?? 0;

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
  }
}

// Small helper to silence unawaited futures.
void unawaited(Future<void> f) {}
