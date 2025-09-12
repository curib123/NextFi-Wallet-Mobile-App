import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

enum SwapDir { xlmToUsdc, usdcToXlm }

class SwapProvider extends ChangeNotifier {
  SwapProvider({required StellarWalletService svc}) : _svc = svc;

  // ---- Constants ----
  static const double dustXlm = 1.0; // keep 1 XLM for reserve/fees
  static const double _EPS = 1e-6;

  // ---- Internal ----
  final StellarWalletService _svc;
  String? _address; // bound from WalletHomeProvider

  StreamSubscription? _acctSub;
  StreamSubscription? _feeSub;

  // ---- Public state ----
  bool loading = true;
  String? error;

  String? get accountId => _address; // expose as read-only

  double xlmBal = 0.0;
  double usdcBal = 0.0;

  double? estReceive;     // latest quote
  double? feeXlm;         // live network fee estimate (in XLM)
  bool needsTrustline = false;

  SwapDir dir = SwapDir.xlmToUsdc;
  bool get isXlmToUsdc => dir == SwapDir.xlmToUsdc;

  bool get isTestnet => _svc.isTestnet ?? identical(_svc.sdk, stellar.StellarSDK.TESTNET);

  // ───────────────── Bind to active wallet address (called by ProxyProvider)
  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      // clear state when wallet is absent
      if (_address != null) {
        _address = null;
        _teardownStreams();
        _clearState();
        loading = false;
        error = 'No wallet found.';
        notifyListeners();
      }
      return;
    }

    if (_address == addr) return; // no change

    // Switch to new wallet
    _address = addr;
    _rebootForAddress();
  }

  // ───────────────── Public API
  Future<void> start() async {
    // Kept for backward compatibility; if already bound, ensure streams running
    if (_address == null || _address!.isEmpty) {
      loading = false;
      error = 'No wallet found.';
      notifyListeners();
      return;
    }
    if (_acctSub == null) {
      await _primeAndWire();
    }
  }

  Future<void> setDir(SwapDir value) async {
    if (dir == value) return;
    dir = value;

    // when direction changes, trustline requirement may change
    needsTrustline = isXlmToUsdc ? needsTrustline : false;
    notifyListeners();

    await _wireFeeStream();
  }

  Future<void> refreshBalances() async {
    final aid = _address;
    if (aid == null || aid.isEmpty) return;
    try {
      final res = await Future.wait<double>([
        _svc.getXlmBalance(aid),
        _svc.getUsdcBalance(aid),
      ]);
      xlmBal = res[0];
      usdcBal = res[1];

      try {
        final hasTl = await _svc.hasUsdcTrustline(aid);
        final prev = needsTrustline;
        needsTrustline = isXlmToUsdc ? !hasTl : false;
        if (prev != needsTrustline) {
          await _wireFeeStream();
        }
      } catch (_) {}

      notifyListeners();
    } catch (_) {
      // keep last balances
    }
  }

  double get availableFrom {
    if (isXlmToUsdc) {
      final spendable = (xlmBal - dustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble());
    }
    return _floor6(usdcBal);
  }

  bool hasEnough(double amount) => amount > 0 && amount <= (availableFrom + _EPS);

  Future<double?> updateQuote(double amount) async {
    if (amount <= 0) {
      if (estReceive != null) {
        estReceive = null;
        notifyListeners();
      }
      return null;
    }

    try {
      final q = isXlmToUsdc
          ? await _svc.quoteXlmToUsdc(amount)
          : await _svc.quoteUsdcToXlm(amount);
      estReceive = q;
      notifyListeners();
      return q;
    } catch (_) {
      return estReceive; // keep last estimate
    }
  }

  /// Execute swap. Provide a [secretSupplier] to fetch S… securely at submit time.
  /// If not provided, it will (optionally) fallback to deriving from the active mnemonic.
  Future<String> executeSwap({
    required double amount,
    required double minOut,
    Future<String?> Function()? secretSupplier,
  }) async {
    final aid = _address;
    if (aid == null || aid.isEmpty) {
      throw StateError('Wallet not ready');
    }

    String? secret;
    if (secretSupplier != null) {
      secret = await secretSupplier();
    }
    // Optional fallback to stored mnemonic (kept for compatibility).
    if (secret == null) {
      final mnemonic = await SeedStorage.getActiveSeed() ?? await SeedStorage.getSeed();
      if (mnemonic == null || mnemonic.isEmpty) {
        throw StateError('No wallet seed available');
      }
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
      secret = kp.secretSeed;
    }

    final txid = isXlmToUsdc
        ? await _svc.swapXlmToUsdc(
        secretSeed: secret, sendAmountXlm: amount, minUsdcOut: minOut)
        : await _svc.swapUsdcToXlm(
        secretSeed: secret, sendAmountUsdc: amount, minXlmOut: minOut);

    // Streams should tick; still fine to refresh eagerly.
    await refreshBalances();
    return txid;
  }

  @override
  void dispose() {
    _teardownStreams();
    super.dispose();
  }

  // ───────────────── Internals
  Future<void> _primeAndWire() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await refreshBalances();
      await _wireAccountStream();
      await _wireFeeStream();

      loading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      loading = false;
      error = 'Failed to initialize swap: $e';
      notifyListeners();
    }
  }

  void _rebootForAddress() {
    _teardownStreams();
    _clearState();
    scheduleMicrotask(() async {
      await _primeAndWire();
    });
  }

  void _clearState() {
    xlmBal = 0;
    usdcBal = 0;
    estReceive = null;
    feeXlm = null;
    needsTrustline = false;
  }

  void _teardownStreams() {
    _acctSub?.cancel();
    _acctSub = null;
    _feeSub?.cancel();
    _feeSub = null;
  }

  Future<void> _wireAccountStream() async {
    final aid = _address;
    if (aid == null || aid.isEmpty) return;

    _acctSub?.cancel();
    _acctSub = _svc.accountStateStream(aid).listen((s) async {
      final oldNeeds = needsTrustline;
      xlmBal = s.xlm;
      usdcBal = s.usdc;
      needsTrustline = isXlmToUsdc ? !s.hasUsdcTrustline : false;
      notifyListeners();

      if (oldNeeds != needsTrustline) {
        await _wireFeeStream();
      }
    }, onError: (_) {
      // keep last known state
    });
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    // base op: PathPaymentStrictSend/Receive (we normalize to 1)
    int ops = 1;

    // include your fee-payment op if you add one (example via current fee)
    int feeStroops = 0;
    try {
      feeStroops = await _svc.getCurrentFeeStroops();
    } catch (_) {}
    if (feeStroops > 0) ops += 1;

    // include ChangeTrust if swapping XLM→USDC and no trustline yet
    if (isXlmToUsdc && needsTrustline) ops += 1;

    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      feeXlm = f.totalXlm;
      notifyListeners();
    }, onError: (_) {
      // keep last feeXlm
    });
  }

  double _floor6(double v) => (v * 1e6).floor() / 1e6;
}
