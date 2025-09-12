// lib/Provider/SwapProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

enum SwapDir { xlmToUsdc, usdcToXlm }

class SwapProvider extends ChangeNotifier {
  SwapProvider({StellarWalletService? svc, bool testnet = false})
      : _svc = svc ?? StellarWalletService(testnet: testnet);

  // ---- Constants ----
  static const double dustXlm = 1.0; // keep 1 XLM for reserve/fees
  static const double _EPS = 1e-6;

  // ---- Internal ----
  final StellarWalletService _svc;
  bool _booted = false;

  StreamSubscription? _acctSub;
  StreamSubscription? _feeSub;

  // ---- Public state ----
  bool loading = true;
  String? error;

  String? accountId;      // G...
  String? _secretSeed;    // S... (memory only)

  double xlmBal = 0.0;
  double usdcBal = 0.0;

  double? estReceive;     // latest quote
  double? feeXlm;         // live network fee estimate (in XLM)
  bool needsTrustline = false;

  SwapDir dir = SwapDir.xlmToUsdc;
  bool get isXlmToUsdc => dir == SwapDir.xlmToUsdc;

  // ---- Lifecycle ----
  Future<void> start() async {
    if (_booted) return;
    _booted = true;
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();

    final mnemonic = await SeedStorage.getSeed();
    if (mnemonic == null || mnemonic.isEmpty) {
      loading = false;
      error = 'No wallet found.';
      notifyListeners();
      return;
    }

    try {
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);

      _secretSeed = kp.secretSeed;
      accountId   = kp.accountId;

      // Prime state before streams tick
      await refreshBalances();

      // Live account stream (balances + trustline changes)
      _acctSub?.cancel();
      _acctSub = _svc.accountStateStream(accountId!).listen((s) async {
        final oldNeeds = needsTrustline;
        xlmBal = s.xlm;
        usdcBal = s.usdc;
        needsTrustline = isXlmToUsdc ? !s.hasUsdcTrustline : false;
        notifyListeners();

        // if trustline requirement toggles, recompute fee stream
        if (oldNeeds != needsTrustline) {
          await _wireFeeStream();
        }
      }, onError: (_) {
        // keep last known state
      });

      // Start fee stream now (based on current dir + trustline state)
      await _wireFeeStream();

      loading = false;
      error = null;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Failed to load Stellar wallet (is the account funded on this network?).';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _acctSub?.cancel();
    _feeSub?.cancel();
    super.dispose();
  }

  // ---- State helpers ----
  double _floor6(double v) => (v * 1e6).floor() / 1e6;

  double get availableFrom {
    if (isXlmToUsdc) {
      final spendable = (xlmBal - dustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble());
    }
    return _floor6(usdcBal);
  }

  bool hasEnough(double amount) => amount > 0 && amount <= (availableFrom + _EPS);

  // ---- Direction ----
  Future<void> setDir(SwapDir value) async {
    if (dir == value) return;
    dir = value;

    // when direction changes, trustline requirement may change
    needsTrustline = isXlmToUsdc ? needsTrustline : false;
    notifyListeners();

    await _wireFeeStream();
  }

  // ---- Balances (manual refresh; streams keep this up-to-date) ----
  Future<void> refreshBalances() async {
    final aid = accountId;
    if (aid == null) return;
    try {
      final res = await Future.wait<double>([
        _svc.getXlmBalance(aid),
        _svc.getUsdcBalance(aid),
      ]);
      xlmBal = res[0];
      usdcBal = res[1];

      // also refresh trustline check (affects fee op count)
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

  // ---- Live fee stream (re-subscribes when opCount context changes) ----
  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    // base op: PathPaymentStrictSend
    int ops = 1;

    // include your fixed XLM fee payment op if configured
    int feeStroops = 0;
    try {
      feeStroops = await _svc.getCurrentFeeStroops();
    } catch (_) {}
    if (feeStroops > 0) ops += 1;

    // include ChangeTrust if swapping XLM→USDC and no trustline yet
    if (isXlmToUsdc && needsTrustline) ops += 1;

    _feeSub = _svc
        .feeEstimateStream(opCount: ops, percentile: 95)
        .listen((f) {
      feeXlm = f.totalXlm;
      notifyListeners();
    }, onError: (_) {
      // keep last feeXlm on error
    });
  }

  // ---- Quotes ----
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
      // keep last estimate if error
      return estReceive;
    }
  }

  // ---- Execute swap ----
  Future<String> executeSwap({
    required double amount,
    required double minOut,
  }) async {
    final seed = _secretSeed;
    if (seed == null) throw StateError('Wallet not ready');

    final txid = isXlmToUsdc
        ? await _svc.swapXlmToUsdc(
        secretSeed: seed, sendAmountXlm: amount, minUsdcOut: minOut)
        : await _svc.swapUsdcToXlm(
        secretSeed: seed, sendAmountUsdc: amount, minXlmOut: minOut);

    // Streams will update balances shortly; a manual refresh is still fine.
    await refreshBalances();
    return txid;
  }
}
