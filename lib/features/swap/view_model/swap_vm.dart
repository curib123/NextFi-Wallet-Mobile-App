// lib/features/swap/view_model/swap_vm.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/features/swap/model/swap_dir.dart';
import 'package:next_fi/features/swap/model/swap_state.dart';
import 'package:next_fi/features/swap/model/swap_mode.dart'; // AmountMode
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';

class SwapVM extends ChangeNotifier {
  SwapVM({
    required StellarWalletServices svc,
    required SeedKeypairVM keypairVM,
  })  : _svc = svc,
        _keys = keypairVM {
    scheduleMicrotask(() async {
      if (_feeSub == null) {
        await _wireFeeStream();
      }
    });
  }

  // ── constants ──────────────────────────────────────────────────────────────
  static const double dustXlm = 1.0; // keep 1 XLM for reserve/fees
  static const double _EPS = 1e-6;

  // Slippage bounds (fraction): 0.5%..5.0%, default 1.0%
  static const double slippageMin = 0.005; // 0.5%
  static const double slippageMax = 0.05;  // 5.0%

  // Convenience percent view for UI (0.5..5.0)
  static double get slippageMinPct => slippageMin * 100; // 0.5
  static double get slippageMaxPct => slippageMax * 100; // 5.0

  // Debounce delay for network quoting while typing
  static const Duration _quoteDebounce = Duration(milliseconds: 120);

  // EMA smoothing factor for rate cache (higher = quicker adaptation)
  static const double _emaAlpha = 0.35;

  // ── deps/internal ──────────────────────────────────────────────────────────
  final StellarWalletServices _svc;
  final SeedKeypairVM _keys;

  StreamSubscription? _acctSub;
  StreamSubscription? _feeSub;

  Timer? _quoteTimer;
  int _quoteSeq = 0; // increments per request; guards against stale updates

  // ── UI mode: enter by "Send" or "Receive" ─────────────────────────────────
  AmountMode _mode = AmountMode.from;
  AmountMode get mode => _mode;

  // ── view-facing ephemeral values (not in SwapState) ───────────────────────
  double _amount = 0.0; // *from-asset* units
  double get amount => _amount;

  // fractional: 0.01 == 1%
  double _slippagePct = 0.01; // default 1%
  double get slippagePct => _slippagePct;

  // quick helpers for UIs that like whole percents
  double get slippagePctPercent => _roundFrac(_slippagePct * 100, 2);
  void setSlippagePctPercent(double pct) => setSlippagePct(pct / 100);

  // Tx/profit fee in XLM (separate from network fee, which is in state.feeXlm)
  double? _txFeeXlm; // may be null until fetched
  double get txFeeXlm => _txFeeXlm ?? 0.0;

  // ── fast path: cached rate (to give instant estimates) ────────────────────
  // For xlm->usdc we store USDC per 1 XLM. For usdc->xlm we store XLM per 1 USDC.
  double? _rateXlmToUsdc;
  double? _rateUsdcToXlm;
  DateTime? _rateUpdatedAt;

  void _bumpRate({required bool xlmToUsdc, required double from, required double to}) {
    if (from <= 0 || to <= 0) return;
    final now = DateTime.now();
    if (xlmToUsdc) {
      final r = to / from; // USDC per XLM
      _rateXlmToUsdc = (_rateXlmToUsdc == null) ? r : _ema(_rateXlmToUsdc!, r, _emaAlpha);
    } else {
      final r = to / from; // XLM per USDC
      _rateUsdcToXlm = (_rateUsdcToXlm == null) ? r : _ema(_rateUsdcToXlm!, r, _emaAlpha);
    }
    _rateUpdatedAt = now;
  }

  double? _getCachedRate({required bool xlmToUsdc}) {
    final r = xlmToUsdc ? _rateXlmToUsdc : _rateUsdcToXlm;
    if (r == null) return null;
    // Expire old rates quickly to avoid stale feel
    if (_rateUpdatedAt != null &&
        DateTime.now().difference(_rateUpdatedAt!) > const Duration(seconds: 30)) {
      return null;
    }
    return r;
  }

  double _ema(double prev, double next, double alpha) => prev + alpha * (next - prev);

  // ── state (immutable data class) ──────────────────────────────────────────
  SwapState _state = const SwapState();
  SwapState get state => _state;
  void _set(SwapState s, {bool notify = true}) {
    _state = s;
    if (notify) notifyListeners();
  }

  bool get isTestnet =>
      _svc.isTestnet ?? identical(_svc.sdk, stellar.StellarSDK.TESTNET);

  // ──────────────────────────────────────────────────────────────────────────
  // Amount & Mode API
  // ──────────────────────────────────────────────────────────────────────────

  /// Switch between entering by **Send** (from) vs **Receive** (to).
  Future<void> setAmountMode(AmountMode value) async {
    if (_mode == value) return;
    _mode = value;

    // When switching to "to", refresh quote so UI can prefill receive field
    if (_mode == AmountMode.to && _amount > 0) {
      _scheduleQuote(_amount, immediateFastPath: true);
    }
    notifyListeners();
  }

  /// Called by UI when text field changes.
  /// - In FROM mode: parse as from-amount (clamped to available).
  /// - In TO mode: parse as desired receive, back-solve the needed from-amount.
  Future<void> onAmountChanged(String raw) async {
    final parsed = double.tryParse(raw.trim()) ?? 0.0;

    if (_mode == AmountMode.to) {
      // Enter-by-Receive: solve for required FROM amount (fast path)
      final desiredOut = parsed <= 0 ? 0.0 : parsed;
      final solvedFrom = await _solveFromForDesiredOutFast(desiredOut);
      final cap = availableFrom;
      final clamped = solvedFrom > cap && cap > 0 ? cap : (solvedFrom <= 0 ? 0.0 : solvedFrom);

      if ((clamped - _amount).abs() < _EPS) {
        // Still schedule a precise quote so estReceive syncs
        _scheduleQuote(_amount, immediateFastPath: true);
        return;
      }

      _amount = _floorTo(clamped, 7);
      // Notify once; precise quote will trigger another notify when it lands
      notifyListeners();
      _scheduleQuote(_amount, immediateFastPath: true);
      if (_feeSub == null) await _wireFeeStream();
      return;
    }

    // Enter-by-Send (FROM)
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

  /// Programmatic set (e.g., percent chips), always in *from* units.
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

  /// Sets slippage as a FRACTION (0.01 == 1%), clamped to 0.5%..5.0%.
  void setSlippagePct(double value) {
    final clamped = value.clamp(slippageMin, slippageMax).toDouble();
    if ((clamped - _slippagePct).abs() < _EPS) return;
    _slippagePct = _roundFrac(clamped, 4); // precision enough for UI at 0.1% step
    notifyListeners();
  }

  Future<double> capAmountToAvailableAndRequote() async {
    final cap = availableFrom;
    if (_amount > cap && cap > 0) {
      await setAmount(cap);
    } else {
      // still ensure quote is up-to-date
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
    final sl = slippagePctPercent; // show human-friendly %
    final slStr = sl % 1 == 0 ? sl.toStringAsFixed(0) : sl.toStringAsFixed(1);

    final feeCombined = estCombinedFeeXlm;
    final feeStr = feeCombined <= 0
        ? ''
        : ' · Est. transaction fee≈ ${fmt(feeCombined)} XLM'
        '${_state.needsTrustline ? ' (incl. trustline)' : ''}';

    return 'Est. receive: $recv ${_state.isXlmToUsdc ? 'USDC' : 'XLM'} · Slippage: $slStr%$feeStr';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Direction / Address binding
  // ──────────────────────────────────────────────────────────────────────────

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
    _set(_state.copyWith(
      accountId: addr,
      xlmBal: 0,
      usdcBal: 0,
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
    if (_acctSub == null) {
      await _primeAndWire();
    }
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

    // Kick a fast estimate using the opposite cached rate
    _scheduleQuote(_amount, immediateFastPath: true);
    await capAmountToAvailableAndRequote();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Balances / Quotes / Fees
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> refreshBalances() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;
    try {
      final res = await Future.wait<double>([
        _svc.getXlmBalance(aid),
        _svc.getUsdcBalance(aid),
      ]);
      final xlm = res[0];
      final usdc = res[1];

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

      if (_amount > 0) {
        _scheduleQuote(_amount, immediateFastPath: true);
      }
    } catch (_) {/* keep last */}
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

  // Public, but now just calls the optimized scheduler (debounced quote)
  Future<double?> updateQuote(double amount) async {
    _scheduleQuote(amount, immediateFastPath: true);
    return _state.estReceive;
  }

  void _scheduleQuote(double amount, {bool immediateFastPath = false}) {
    // First: fast path — update UI instantly using cached rate
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

    // Debounce the precise network quote
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
        if (mySeq != _quoteSeq) return; // stale
        if (q != null && q > 0) {
          _bumpRate(
            xlmToUsdc: _state.isXlmToUsdc,
            from: amount,
            to: q,
          );
          _set(_state.copyWith(estReceive: q));
        }
      } catch (_) {
        // keep last estimate; ignore error (prevents flicker)
      }
    });
  }

  double? _fastEstimate(double amount) {
    if (amount <= 0) return null;
    final r = _getCachedRate(xlmToUsdc: _state.isXlmToUsdc);
    if (r == null) return _state.estReceive; // fallback: keep last
    return _roundFrac(amount * r, 7);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Swap execution
  // ──────────────────────────────────────────────────────────────────────────

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

    await refreshBalances();
    return txid;
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _teardownStreams();
    super.dispose();
  }

  // ── internals ──────────────────────────────────────────────────────────────
  Future<void> _primeAndWire() async {
    _set(_state.copyWith(loading: true, error: ''));
    try {
      await refreshBalances();
      await _wireAccountStream();
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
    _acctSub?.cancel();
    _acctSub = null;
    _feeSub?.cancel();
    _feeSub = null;
  }

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
      if (prevNeeds != _state.needsTrustline) {
        await _wireFeeStream();
      }
      if (_amount > 0) {
        await capAmountToAvailableAndRequote();
      }
    }, onError: (_) {/* keep last */});
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    // 1) Refresh transaction/profit fee (in XLM)
    try {
      final x = await _svc.getCurrentFeeXlm();
      if ((x - (_txFeeXlm ?? 0.0)).abs() > _EPS) {
        _txFeeXlm = x;
        notifyListeners();
      }
    } catch (_) {/* keep last */}

    // 2) Determine op-count for network fee estimation
    int ops = 1; // swap op
    int feeStroops = 0;
    try {
      feeStroops = await _svc.getCurrentFeeStroops();
    } catch (_) {}
    if (feeStroops > 0) ops += 1; // pay tx-fee op
    if (_state.isXlmToUsdc && _state.needsTrustline) ops += 1; // trustline op

    // 3) Stream network fee estimates
    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      if ((_state.feeXlm ?? 0.0) != f.totalXlm) {
        _set(_state.copyWith(feeXlm: f.totalXlm));
      }
    }, onError: (_) {/* keep last */});
  }

  // ── fast “receive-mode” solver with 1–2 precise quotes ────────────────────
  Future<double> _solveFromForDesiredOutFast(double desiredOut) async {
    if (desiredOut <= 0) return 0.0;

    // 1) Use cached rate to guess quickly
    final r = _getCachedRate(xlmToUsdc: _state.isXlmToUsdc);
    double guess = (r == null)
        ? (_amount > 0 ? _amount : desiredOut) // fallback
        : (desiredOut / r);

    // clamp to feasible range
    final cap = availableFrom;
    if (cap <= 0) return 0.0;
    if (guess > cap) guess = cap;

    // 2) One precise quote at guess
    final q1 = await (_state.isXlmToUsdc
        ? _svc.quoteXlmToUsdc(guess)
        : _svc.quoteUsdcToXlm(guess));
    final q1v = (q1 ?? 0.0).toDouble();

    // If null or zero (unlikely), return guess and let debounced quote refine later
    if (q1v <= 0) return guess;

    // Keep rate fresh
    _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: guess, to: q1v);

    // Perfectly matched already
    final diff = (q1v - desiredOut).abs();
    if (diff <= 1e-7) return guess;

    // 3) Proportional correction (assume near-linear short range)
    // from2 ≈ guess * desiredOut / q1
    double corr = guess * desiredOut / q1v;
    if (corr > cap) corr = cap;
    if ((corr - guess).abs() < 1e-9) return corr;

    // 4) One more precise quote for corr; then stop.
    final q2 = await (_state.isXlmToUsdc
        ? _svc.quoteXlmToUsdc(corr)
        : _svc.quoteUsdcToXlm(corr));
    final q2v = (q2 ?? 0.0).toDouble();
    if (q2v > 0) {
      _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: corr, to: q2v);
    }

    return _floorTo(corr, 7);
  }

  // ── math/utils ────────────────────────────────────────────────────────────
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
