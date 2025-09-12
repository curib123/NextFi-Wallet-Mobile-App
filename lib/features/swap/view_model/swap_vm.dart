// lib/features/swap/viewmodel/swap_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

import '../model/swap_state.dart';
import '../model/swap_dir.dart';

class SwapVM extends ChangeNotifier {
  SwapVM({required StellarWalletService svc}) : _svc = svc;

  // ---- constants ----
  static const double dustXlm = 1.0; // keep 1 XLM for reserve/fees
  static const double _EPS = 1e-6;

  // ---- deps/internal ----
  final StellarWalletService _svc;
  StreamSubscription? _acctSub;
  StreamSubscription? _feeSub;

  // ---- state ----
  SwapState _state = const SwapState();
  SwapState get state => _state;
  void _set(SwapState s) { _state = s; notifyListeners(); }

  // public helpers
  bool get isTestnet => _svc.isTestnet ?? identical(_svc.sdk, stellar.StellarSDK.TESTNET);

  // ─── bind to active wallet (address can change) ────────────────────────────
  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      _teardownStreams();
      _set(_state.copyWith(
        accountId: null,
        xlmBal: 0, usdcBal: 0,
        estReceive: null, feeXlm: null,
        needsTrustline: false,
        loading: false,
        error: 'No wallet found.',
      ));
      return;
    }
    if (_state.accountId == addr) return;

    _teardownStreams();
    _set(_state.copyWith(
      accountId: addr,
      xlmBal: 0, usdcBal: 0,
      estReceive: null, feeXlm: null,
      needsTrustline: false,
      loading: true,
      error: '',
    ));
    scheduleMicrotask(() async { await _primeAndWire(); });
  }

  Future<void> start() async {
    if ((_state.accountId ?? '').isEmpty) {
      _set(_state.copyWith(loading: false, error: 'No wallet found.'));
      return;
    }
    if (_acctSub == null) {
      await _primeAndWire();
    }
  }

  Future<void> setDir(SwapDir value) async {
    if (_state.dir == value) return;
    // when direction changes, trustline requirement may change
    final needs = value == SwapDir.xlmToUsdc ? _state.needsTrustline : false;
    _set(_state.copyWith(dir: value, needsTrustline: needs));
    await _wireFeeStream();
  }

  Future<void> refreshBalances() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;
    try {
      final res = await Future.wait<double>([
        _svc.getXlmBalance(aid),
        _svc.getUsdcBalance(aid),
      ]);
      var xlm = res[0];
      var usdc = res[1];

      bool needs = _state.needsTrustline;
      try {
        final hasTl = await _svc.hasUsdcTrustline(aid);
        needs = _state.isXlmToUsdc ? !hasTl : false;
      } catch (_) {}

      _set(_state.copyWith(
        xlmBal: xlm,
        usdcBal: usdc,
        needsTrustline: needs,
      ));
      await _wireFeeStream();
    } catch (_) {/* keep last */}
  }

  double get availableFrom {
    if (_state.isXlmToUsdc) {
      final spendable = (_state.xlmBal - dustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble());
    }
    return _floor6(_state.usdcBal);
  }

  bool hasEnough(double amount) => amount > 0 && amount <= (availableFrom + _EPS);

  Future<double?> updateQuote(double amount) async {
    if (amount <= 0) {
      if (_state.estReceive != null) _set(_state.copyWith(estReceive: null));
      return null;
    }
    try {
      final q = _state.isXlmToUsdc
          ? await _svc.quoteXlmToUsdc(amount)
          : await _svc.quoteUsdcToXlm(amount);
      _set(_state.copyWith(estReceive: q));
      return q;
    } catch (_) {
      return _state.estReceive; // keep last estimate
    }
  }

  /// Execute swap. Provide a [secretSupplier] to fetch S… securely at submit time.
  /// If not provided, it will (optionally) fallback to deriving from the active mnemonic.
  Future<String> executeSwap({
    required double amount,
    required double minOut,
    Future<String?> Function()? secretSupplier,
  }) async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) {
      throw StateError('Wallet not ready');
    }

    String? secret;
    if (secretSupplier != null) {
      secret = await secretSupplier();
    }
    if (secret == null) {
      final mnemonic = await SeedStorage.getActiveSeed() ?? await SeedStorage.getSeed();
      if (mnemonic == null || mnemonic.isEmpty) {
        throw StateError('No wallet seed available');
      }
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
      secret = kp.secretSeed;
    }

    final txid = _state.isXlmToUsdc
        ? await _svc.swapXlmToUsdc(secretSeed: secret, sendAmountXlm: amount, minUsdcOut: minOut)
        : await _svc.swapUsdcToXlm(secretSeed: secret, sendAmountUsdc: amount, minXlmOut: minOut);

    await refreshBalances(); // streams will tick anyway
    return txid;
  }

  @override
  void dispose() { _teardownStreams(); super.dispose(); }

  // ─── internals ────────────────────────────────────────────────────────────
  Future<void> _primeAndWire() async {
    _set(_state.copyWith(loading: true, error: ''));
    try {
      await refreshBalances();
      await _wireAccountStream();
      await _wireFeeStream();
      _set(_state.copyWith(loading: false, error: ''));
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to initialize swap: $e'));
    }
  }

  void _teardownStreams() { _acctSub?.cancel(); _acctSub = null; _feeSub?.cancel(); _feeSub = null; }

  Future<void> _wireAccountStream() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;

    _acctSub?.cancel();
    _acctSub = _svc.accountStateStream(aid).listen((s) async {
      final prevNeeds = _state.needsTrustline;
      _set(_state.copyWith(
        xlmBal: s.xlm,
        usdcBal: s.usdc,
        needsTrustline: _state.isXlmToUsdc ? !s.hasUsdcTrustline : false,
      ));
      if (prevNeeds != _state.needsTrustline) { await _wireFeeStream(); }
    }, onError: (_) {/* keep last */});
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    int ops = 1; // swap op
    int feeStroops = 0;
    try { feeStroops = await _svc.getCurrentFeeStroops(); } catch (_) {}
    if (feeStroops > 0) ops += 1;
    if (_state.isXlmToUsdc && _state.needsTrustline) ops += 1;

    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      _set(_state.copyWith(feeXlm: f.totalXlm));
    }, onError: (_) {/* keep last */});
  }

  double _floor6(double v) => (v * 1e6).floor() / 1e6;
}
