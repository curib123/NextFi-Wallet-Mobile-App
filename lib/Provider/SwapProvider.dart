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

  // ---- Public state ----
  bool loading = true;
  String? error;

  String? accountId;      // G...
  String? _secretSeed;    // S... (kept in memory only; not persisted here)

  double xlmBal = 0.0;
  double usdcBal = 0.0;

  double? estReceive;     // latest quote result (depends on amount + dir)
  double? feeXlm;         // estimated fee in XLM
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

      await refreshBalances();

      // Auto-refresh balances when payments stream in.
      // (If your StellarWalletService returns a subscription, you can hold/cancel it.)
      _svc.streamPayments(accountId!, (_) => refreshBalances());

      loading = false;
      error = null;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Failed to load Stellar wallet (is the account funded on mainnet?).';
      notifyListeners();
    }
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
    notifyListeners();
    await updateFeeEstimate(); // fee changes if we need trustline for XLM→USDC
  }

  // ---- Refreshes ----
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
      notifyListeners();

      await updateFeeEstimate();
    } catch (_) {
      // keep last balances/fee
    }
  }

  Future<void> updateFeeEstimate() async {
    final aid = accountId;
    if (aid == null) return;

    // One op for the swap itself
    int opCount = 1;

    // If swapping XLM→USDC and no USDC trustline yet, include a ChangeTrust op
    bool needsTl = false;
    if (isXlmToUsdc) {
      try {
        needsTl = !(await _svc.hasUsdcTrustline(aid));
      } catch (_) {
        needsTl = false;
      }
      if (needsTl) opCount += 1;
    }

    double? fee;
    try {
      fee = await _svc.estimateNetworkFeeXlm(opCount: opCount, percentile: 95);
    } catch (_) {
      fee = null;
    }

    needsTrustline = needsTl;
    feeXlm = fee;
    notifyListeners();
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

    // After submit, refresh balances + fee/quote state
    await refreshBalances();
    return txid;
  }
}
