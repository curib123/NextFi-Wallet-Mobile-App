// lib/features/swap/view_model/swap_vm.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/features/swap/model/swap_dir.dart';
import 'package:next_fi/features/swap/model/swap_state.dart';
import 'package:next_fi/features/swap/model/swap_mode.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';

class SwapVM extends ChangeNotifier {
  SwapVM({
    required StellarWalletServices svc,
    required SeedKeypairVM keypairVM,
    required WalletHomeVM walletHomeVM,
  })  : _svc = svc,
        _keys = keypairVM,
        _walletHomeVM = walletHomeVM {
    // Listen to wallet home balance changes
    _walletHomeVM.addListener(_onWalletHomeChanged);

    scheduleMicrotask(() async {
      if (_feeSub == null) {
        await _wireFeeStream();
      }
    });
  }

  // ── constants ──────────────────────────────────────────────────────────────
  static const double dustXlm = 1.0;
  static const double _EPS = 1e-6;

  static const double slippageMin = 0.005;
  static const double slippageMax = 0.05;

  static double get slippageMinPct => slippageMin * 100;
  static double get slippageMaxPct => slippageMax * 100;

  static const Duration _quoteDebounce = Duration(milliseconds: 120);
  static const double _emaAlpha = 0.35;

  // ── deps/internal ──────────────────────────────────────────────────────────
  final StellarWalletServices _svc;
  final SeedKeypairVM _keys;
  final WalletHomeVM _walletHomeVM;

  StreamSubscription? _feeSub;

  Timer? _quoteTimer;
  int _quoteSeq = 0;

  // ── UI mode ────────────────────────────────────────────────────────────────
  AmountMode _mode = AmountMode.from;
  AmountMode get mode => _mode;

  // ── ephemeral values ───────────────────────────────────────────────────────
  double _amount = 0.0;
  double get amount => _amount;

  double _slippagePct = 0.01;
  double get slippagePct => _slippagePct;

  double get slippagePctPercent => _roundFrac(_slippagePct * 100, 2);
  void setSlippagePctPercent(double pct) => setSlippagePct(pct / 100);

  double? _txFeeXlm;
  double get txFeeXlm => _txFeeXlm ?? 0.0;

  // ── cached rate ────────────────────────────────────────────────────────────
  double? _rateXlmToUsdc;
  double? _rateUsdcToXlm;
  DateTime? _rateUpdatedAt;

  void _bumpRate({required bool xlmToUsdc, required double from, required double to}) {
    if (from <= 0 || to <= 0) return;
    final now = DateTime.now();
    if (xlmToUsdc) {
      final r = to / from;
      _rateXlmToUsdc = (_rateXlmToUsdc == null) ? r : _ema(_rateXlmToUsdc!, r, _emaAlpha);
    } else {
      final r = to / from;
      _rateUsdcToXlm = (_rateUsdcToXlm == null) ? r : _ema(_rateUsdcToXlm!, r, _emaAlpha);
    }
    _rateUpdatedAt = now;
  }

  double? _getCachedRate({required bool xlmToUsdc}) {
    final r = xlmToUsdc ? _rateXlmToUsdc : _rateUsdcToXlm;
    if (r == null) return null;
    if (_rateUpdatedAt != null &&
        DateTime.now().difference(_rateUpdatedAt!) > const Duration(seconds: 30)) {
      return null;
    }
    return r;
  }

  double _ema(double prev, double next, double alpha) => prev + alpha * (next - prev);

  // ── state ──────────────────────────────────────────────────────────────────
  SwapState _state = const SwapState();
  SwapState get state => _state;
  void _set(SwapState s, {bool notify = true}) {
    _state = s;
    if (notify) notifyListeners();
  }

  bool get isTestnet =>
      _svc.isTestnet ?? identical(_svc.sdk, stellar.StellarSDK.TESTNET);

  // ── Wallet home integration ────────────────────────────────────────────────
  void _onWalletHomeChanged() {
    final homeState = _walletHomeVM.state;

    // Update balances from wallet home
    final xlm = homeState.xlm;
    final usdc = homeState.usdc;

    if (xlm != _state.xlmBal || usdc != _state.usdcBal) {
      _set(_state.copyWith(
        xlmBal: xlm,
        usdcBal: usdc,
      ));

      // Re-check amount cap
      if (_amount > 0) {
        scheduleMicrotask(() => capAmountToAvailableAndRequote());
      }
    }
  }

  // ── Amount & Mode API ──────────────────────────────────────────────────────
  Future<void> setAmountMode(AmountMode value) async {
    if (_mode == value) return;
    _mode = value;

    if (_mode == AmountMode.to && _amount > 0) {
      _scheduleQuote(_amount, immediateFastPath: true);
    }
    notifyListeners();
  }

  Future<void> onAmountChanged(String raw) async {
    final parsed = double.tryParse(raw.trim()) ?? 0.0;

    if (_mode == AmountMode.to) {
      final desiredOut = parsed <= 0 ? 0.0 : parsed;
      final solvedFrom = await _solveFromForDesiredOutFast(desiredOut);
      final cap = availableFrom;
      final clamped = solvedFrom > cap && cap > 0 ? cap : (solvedFrom <= 0 ? 0.0 : solvedFrom);

      if ((clamped - _amount).abs() < _EPS) {
        _scheduleQuote(_amount, immediateFastPath: true);
        return;
      }

      _amount = _floorTo(clamped, 7);
      notifyListeners();
      _scheduleQuote(_amount, immediateFastPath: true);
      if (_feeSub == null) await _wireFeeStream();
      return;
    }

    final v = parsed;
    if ((v - _amount).abs() < _EPS) return;

    final cap = availableFrom;
    final clamped = v > cap && cap > 0 ? cap : (v <= 0 ? 0.0 : v);

    _amount = _floorTo(clamped, 7);
    notifyListeners();

    _scheduleQuote(_amount, immediateFastPath: true);

    if (_feeSub == null) {
      await _wireFeeStream();
    }
  }

  Future<void> setAmount(double value) async {
    final cap = availableFrom;
    final clamped = value > cap && cap > 0 ? cap : (value <= 0 ? 0.0 : value);
    _amount = _floorTo(clamped, 7);
    notifyListeners();
    _scheduleQuote(_amount, immediateFastPath: true);
    if (_feeSub == null) {
      await _wireFeeStream();
    }
  }

  Future<double> applyPercent(double percent) async {
    final base = availableFrom;
    final v = _floorTo(base * percent, 7);
    await setAmount(v <= 0 ? 0.0 : v);
    return _amount;
  }

  void setSlippagePct(double value) {
    final clamped = value.clamp(slippageMin, slippageMax).toDouble();
    if ((clamped - _slippagePct).abs() < _EPS) return;
    _slippagePct = _roundFrac(clamped, 4);
    notifyListeners();
  }

  Future<double> capAmountToAvailableAndRequote() async {
    final cap = availableFrom;
    if (_amount > cap && cap > 0) {
      await setAmount(cap);
    } else {
      _scheduleQuote(_amount, immediateFastPath: true);
    }
    return _amount;
  }

  bool get hasAmount => _amount > 0;
  bool get canSwap => _amount > 0 && hasEnough(_amount) && !_state.loading;

  double get estNetworkFeeXlm => _state.feeXlm ?? 0.0;
  double get estCombinedFeeXlm => estNetworkFeeXlm + txFeeXlm;
  bool get hasFeeEstimates => estNetworkFeeXlm > 0 || txFeeXlm > 0;

  double? get currentMinOutPreFee {
    final est = _state.estReceive;
    if (est == null) return null;
    return est * (1 - _slippagePct);
  }

  double? get currentMinOutAfterFees {
    final pre = currentMinOutPreFee;
    if (pre == null) return null;
    if (_state.isXlmToUsdc) return pre;
    final after = (pre - txFeeXlm);
    return after <= 0 ? 0.0 : after;
  }

  String buildQuoteLine(String Function(num) fmt) {
    if (_state.estReceive == null) return 'Getting live quote…';
    final recv = fmt(_state.estReceive!);
    final sl = slippagePctPercent;
    final slStr = sl % 1 == 0 ? sl.toStringAsFixed(0) : sl.toStringAsFixed(1);

    final feeCombined = estCombinedFeeXlm;
    final feeStr = feeCombined <= 0
        ? ''
        : ' · Est. transaction fee≈ ${fmt(feeCombined)} XLM'
        '${_state.needsTrustline ? ' (incl. trustline)' : ''}';

    return 'Est. receive: $recv ${_state.isXlmToUsdc ? 'USDC' : 'XLM'} · Slippage: $slStr%$feeStr';
  }

  // ── Direction / Address binding ────────────────────────────────────────────
  void bindToActiveWallet() => bindToAddress(_keys.accountId);

  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      _teardownStreams();
      _txFeeXlm = null;
      _set(_state.copyWith(
        accountId: null,
        xlmBal: 0,
        usdcBal: 0,
        estReceive: null,
        feeXlm: null,
        needsTrustline: false,
        loading: false,
        error: 'No wallet found.',
      ));
      return;
    }
    if (_state.accountId == addr) return;

    _teardownStreams();
    _txFeeXlm = null;

    // Use balances from wallet home if available
    final homeState = _walletHomeVM.state;
    final xlm = homeState.address == addr ? homeState.xlm : 0.0;
    final usdc = homeState.address == addr ? homeState.usdc : 0.0;

    _set(_state.copyWith(
      accountId: addr,
      xlmBal: xlm,
      usdcBal: usdc,
      estReceive: null,
      feeXlm: null,
      needsTrustline: false,
      loading: true,
      error: '',
    ));

    scheduleMicrotask(() async {
      await _primeAndWire();
    });
  }

  Future<void> start() async {
    if ((_state.accountId ?? '').isEmpty) {
      _set(_state.copyWith(loading: false, error: 'No wallet found.'));
      return;
    }
    await _primeAndWire();
  }

  Future<double> flipDirectionAndRequote() async {
    final newDir = _state.isXlmToUsdc ? SwapDir.usdcToXlm : SwapDir.xlmToUsdc;
    await setDir(newDir);
    return await capAmountToAvailableAndRequote();
  }

  Future<void> setDir(SwapDir value) async {
    if (_state.dir == value) return;
    final needs = value == SwapDir.xlmToUsdc ? _state.needsTrustline : false;
    _set(_state.copyWith(dir: value, needsTrustline: needs));
    await _wireFeeStream();

    _scheduleQuote(_amount, immediateFastPath: true);
    await capAmountToAvailableAndRequote();
  }

  // ── Balances / Quotes / Fees ───────────────────────────────────────────────
  Future<void> refreshBalances() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;

    // Prefer wallet home balances if available
    final homeState = _walletHomeVM.state;
    if (homeState.address == aid) {
      _set(_state.copyWith(
        xlmBal: homeState.xlm,
        usdcBal: homeState.usdc,
      ));
    } else {
      // Fallback: fetch directly
      try {
        final res = await Future.wait<double>([
          _svc.getXlmBalance(aid),
          _svc.getUsdcBalance(aid),
        ]);
        _set(_state.copyWith(
          xlmBal: res[0],
          usdcBal: res[1],
        ));
      } catch (_) {}
    }

    // Check trustline
    bool needs = _state.needsTrustline;
    try {
      final hasTl = await _svc.hasUsdcTrustline(aid);
      needs = _state.isXlmToUsdc ? !hasTl : false;
    } catch (_) {}

    _set(_state.copyWith(needsTrustline: needs));
    await _wireFeeStream();

    if (_amount > 0) {
      _scheduleQuote(_amount, immediateFastPath: true);
    }
  }

  double get availableFrom {
    if (_state.isXlmToUsdc) {
      final spendable = (_state.xlmBal - dustXlm).clamp(0, double.infinity);
      return _floor6(spendable.toDouble());
    }
    return _floor6(_state.usdcBal);
  }

  bool hasEnough(double amount) =>
      amount > 0 && amount <= (availableFrom + _EPS);

  Future<double?> updateQuote(double amount) async {
    _scheduleQuote(amount, immediateFastPath: true);
    return _state.estReceive;
  }

  void _scheduleQuote(double amount, {bool immediateFastPath = false}) {
    if (immediateFastPath) {
      final fast = _fastEstimate(amount);
      if (fast != null) {
        _set(_state.copyWith(estReceive: fast), notify: true);
      } else {
        if (amount <= 0 && _state.estReceive != null) {
          _set(_state.copyWith(estReceive: null), notify: true);
        }
      }
    }

    _quoteTimer?.cancel();
    if (amount <= 0) {
      _quoteTimer = Timer(_quoteDebounce, () {
        if (_state.estReceive != null) {
          _set(_state.copyWith(estReceive: null));
        }
      });
      return;
    }

    final mySeq = ++_quoteSeq;
    _quoteTimer = Timer(_quoteDebounce, () async {
      try {
        final q = _state.isXlmToUsdc
            ? await _svc.quoteXlmToUsdc(amount)
            : await _svc.quoteUsdcToXlm(amount);
        if (mySeq != _quoteSeq) return;
        if (q != null && q > 0) {
          _bumpRate(
            xlmToUsdc: _state.isXlmToUsdc,
            from: amount,
            to: q,
          );
          _set(_state.copyWith(estReceive: q));
        }
      } catch (_) {}
    });
  }

  double? _fastEstimate(double amount) {
    if (amount <= 0) return null;
    final r = _getCachedRate(xlmToUsdc: _state.isXlmToUsdc);
    if (r == null) return _state.estReceive;
    return _roundFrac(amount * r, 7);
  }

  // ── Swap execution ─────────────────────────────────────────────────────────
  Future<String> executeSwap({
    required double amount,
    required double minOut,
  }) async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) {
      throw StateError('Wallet not ready');
    }

    final kp = await _keys.deriveKeyPair();

    final txid = _state.isXlmToUsdc
        ? await _svc.swapXlmToUsdc(
      keyPair: kp,
      sendAmountXlm: amount,
      minUsdcOut: minOut,
    )
        : await _svc.swapUsdcToXlm(
      keyPair: kp,
      sendAmountUsdc: amount,
      minXlmOut: minOut,
    );

    // Trigger wallet home refresh
    await _walletHomeVM.refresh(force: true);

    return txid;
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _teardownStreams();
    _walletHomeVM.removeListener(_onWalletHomeChanged);
    super.dispose();
  }

  // ── internals ──────────────────────────────────────────────────────────────
  Future<void> _primeAndWire() async {
    _set(_state.copyWith(loading: true, error: ''));
    try {
      await refreshBalances();
      await _wireFeeStream();
      _set(_state.copyWith(loading: false, error: ''));
      if (_amount > 0) {
        _scheduleQuote(_amount, immediateFastPath: true);
      }
    } catch (e) {
      _set(_state.copyWith(
          loading: false, error: 'Failed to initialize swap: $e'));
    }
  }

  void _teardownStreams() {
    _feeSub?.cancel();
    _feeSub = null;
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    try {
      final x = await _svc.getCurrentFeeXlm();
      if ((x - (_txFeeXlm ?? 0.0)).abs() > _EPS) {
        _txFeeXlm = x;
        notifyListeners();
      }
    } catch (_) {}

    int ops = 1;
    int feeStroops = 0;
    try {
      feeStroops = await _svc.getCurrentFeeStroops();
    } catch (_) {}
    if (feeStroops > 0) ops += 1;
    if (_state.isXlmToUsdc && _state.needsTrustline) ops += 1;

    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      if ((_state.feeXlm ?? 0.0) != f.totalXlm) {
        _set(_state.copyWith(feeXlm: f.totalXlm));
      }
    }, onError: (_) {});
  }

  Future<double> _solveFromForDesiredOutFast(double desiredOut) async {
    if (desiredOut <= 0) return 0.0;

    final r = _getCachedRate(xlmToUsdc: _state.isXlmToUsdc);
    double guess = (r == null)
        ? (_amount > 0 ? _amount : desiredOut)
        : (desiredOut / r);

    final cap = availableFrom;
    if (cap <= 0) return 0.0;
    if (guess > cap) guess = cap;

    final q1 = await (_state.isXlmToUsdc
        ? _svc.quoteXlmToUsdc(guess)
        : _svc.quoteUsdcToXlm(guess));
    final q1v = (q1 ?? 0.0).toDouble();

    if (q1v <= 0) return guess;

    _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: guess, to: q1v);

    final diff = (q1v - desiredOut).abs();
    if (diff <= 1e-7) return guess;

    double corr = guess * desiredOut / q1v;
    if (corr > cap) corr = cap;
    if ((corr - guess).abs() < 1e-9) return corr;

    final q2 = await (_state.isXlmToUsdc
        ? _svc.quoteXlmToUsdc(corr)
        : _svc.quoteUsdcToXlm(corr));
    final q2v = (q2 ?? 0.0).toDouble();
    if (q2v > 0) {
      _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: corr, to: q2v);
    }

    return _floorTo(corr, 7);
  }

  // ── math/utils ─────────────────────────────────────────────────────────────
  double _floor6(double v) => (v * 1e6).floor() / 1e6;

  double _floorTo(double v, int dec) {
    final scale = math.pow(10, dec);
    return (v >= 0 ? (v * scale).floor() / scale : (v * scale).ceil() / scale)
        .toDouble();
  }

  double _roundFrac(double v, int places) {
    final m = math.pow(10, places).toDouble();
    return (v * m).roundToDouble() / m;
  }
}