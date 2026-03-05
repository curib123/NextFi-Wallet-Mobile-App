// lib/features/swap/view_model/swap_vm.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

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
  }) : _svc = svc,
       _keys = keypairVM,
       _walletHomeVM = walletHomeVM {
    _walletHomeVM.addListener(_onWalletHomeChanged);
    scheduleMicrotask(_wireFeeStream);
  }

  // ── constants ──────────────────────────────────────────────────────────────

  static const double _EPS = 1e-6;

  static const double slippageMin = 0.005;
  static const double slippageMax = 0.05;
  static double get slippageMinPct => slippageMin * 100;
  static double get slippageMaxPct => slippageMax * 100;

  static const Duration _quoteDebounce = Duration(milliseconds: 120);
  static const double _emaAlpha = 0.35;

  // ── deps ───────────────────────────────────────────────────────────────────

  final StellarWalletServices _svc;
  final SeedKeypairVM _keys;
  final WalletHomeVM _walletHomeVM;

  StreamSubscription? _feeSub;
  Timer? _quoteTimer;
  int _quoteSeq = 0;

  // ── UI mode ────────────────────────────────────────────────────────────────

  AmountMode _mode = AmountMode.from;
  AmountMode get mode => _mode;

  // ── values ─────────────────────────────────────────────────────────────────

  double _amount = 0.0;
  double _slippagePct = 0.01;
  double? _txFeeXlm;
  double _trustlineReserveXlm =
      StellarWalletServices.defaultReceiverActivationXlm / 2.0;

  double get amount => _amount;
  double get slippagePct => _slippagePct;
  double get txFeeXlm => _txFeeXlm ?? 0.0;
  double get trustlineReserveXlm => _trustlineReserveXlm;

  double get slippagePctPercent => _roundFrac(_slippagePct * 100, 2);
  void setSlippagePctPercent(double pct) => setSlippagePct(pct / 100);

  // ── rate cache ─────────────────────────────────────────────────────────────

  double? _rateXlmToUsdc;
  double? _rateUsdcToXlm;
  DateTime? _rateUpdatedAt;

  void _bumpRate({
    required bool xlmToUsdc,
    required double from,
    required double to,
  }) {
    if (from <= 0 || to <= 0) return;
    final r = to / from;
    if (xlmToUsdc) {
      _rateXlmToUsdc = _rateXlmToUsdc == null ? r : _ema(_rateXlmToUsdc!, r);
    } else {
      _rateUsdcToXlm = _rateUsdcToXlm == null ? r : _ema(_rateUsdcToXlm!, r);
    }
    _rateUpdatedAt = DateTime.now();
  }

  double? _cachedRate({required bool xlmToUsdc}) {
    final r = xlmToUsdc ? _rateXlmToUsdc : _rateUsdcToXlm;
    if (r == null) return null;
    final stale = _rateUpdatedAt == null
        ? true
        : DateTime.now().difference(_rateUpdatedAt!) >
              const Duration(seconds: 30);
    return stale ? null : r;
  }

  double _ema(double prev, double next) => prev + _emaAlpha * (next - prev);

  // ── state ──────────────────────────────────────────────────────────────────

  SwapState _state = const SwapState();
  SwapState get state => _state;

  void _set(SwapState s, {bool notify = true}) {
    _state = s;
    if (notify) notifyListeners();
  }

  bool get isTestnet => _svc.isTestnet;

  // ── Wallet home sync ───────────────────────────────────────────────────────

  void _onWalletHomeChanged() {
    final home = _walletHomeVM.state;
    if (home.xlm == _state.xlmBal && home.usdc == _state.usdcBal) return;
    _set(_state.copyWith(xlmBal: home.xlm, usdcBal: home.usdc));
    if (_amount > 0) scheduleMicrotask(capAmountToAvailableAndRequote);
  }

  // ── Fee getters ────────────────────────────────────────────────────────────

  double get estNetworkFeeXlm => _state.feeXlm ?? 0.0;
  double get estCombinedFeeXlm => estNetworkFeeXlm + txFeeXlm;
  bool get hasFeeEstimates => estNetworkFeeXlm > 0 || txFeeXlm > 0;

  // ── Available balance (fee-deducted) ───────────────────────────────────────

  /// Maximum XLM or USDC the user can swap right now.
  ///
  /// XLM → USDC:
  ///   sendable = balance − networkFees − txFee − safetyBuffer
  ///
  ///   The locked reserve is already excluded from [xlmBal] by the wallet layer.
  ///   Here we only subtract live fees so [_amount] is exactly what hits the DEX.
  ///
  /// USDC → XLM:
  ///   sendable = full USDC balance
  ///   (XLM fees come from the XLM balance, not the USDC amount)
  double get availableFrom {
    if (_state.isXlmToUsdc) {
      // Reserve network fees + safety buffer. The 0.3% swap fee is deducted
      // inside the service from the send amount, so no division needed here.
      final kept = _requiredXlmNonAmountBudget(
        includeTrustlineReserve: _state.needsTrustline,
      );
      return _floor6((_state.xlmBal - kept).clamp(0.0, double.infinity));
    }
    // USDC→XLM: full balance is sendable; service deducts its fee internally.
    return _floor6(_state.usdcBal);
  }

  bool hasEnough(double amount) => amount > 0 && amount <= availableFrom + _EPS;
  bool get _hasEnoughXlmForFees =>
      _state.xlmBal >=
      _requiredXlmNonAmountBudget(
        includeTrustlineReserve: _state.needsTrustline,
      ) -
          _EPS;

  // ── Amount API ─────────────────────────────────────────────────────────────

  Future<void> setAmountMode(AmountMode value) async {
    if (_mode == value) return;
    _mode = value;
    if (_mode == AmountMode.to && _amount > 0) _scheduleQuote(_amount);
    notifyListeners();
  }

  Future<void> onAmountChanged(String raw) async {
    final parsed = double.tryParse(raw.trim()) ?? 0.0;

    if (_mode == AmountMode.to) {
      final fromSolved = await _solveFromForDesiredOut(
        parsed <= 0 ? 0.0 : parsed,
      );
      final clamped = _clamp(fromSolved);
      if ((clamped - _amount).abs() < _EPS) {
        _scheduleQuote(_amount);
        return;
      }
      _amount = _floorTo(clamped, 7);
      notifyListeners();
      _scheduleQuote(_amount);
      return;
    }

    final clamped = _clamp(parsed);
    if ((clamped - _amount).abs() < _EPS) return;
    _amount = _floorTo(clamped, 7);
    notifyListeners();
    _scheduleQuote(_amount);
  }

  Future<void> setAmount(double value) async {
    _amount = _floorTo(_clamp(value), 7);
    notifyListeners();
    _scheduleQuote(_amount);
  }

  Future<double> applyPercent(double percent) async {
    await setAmount(_floorTo(availableFrom * percent, 7));
    return _amount;
  }

  void setSlippagePct(double value) {
    final c = value.clamp(slippageMin, slippageMax);
    if ((c - _slippagePct).abs() < _EPS) return;
    _slippagePct = _roundFrac(c, 4);
    notifyListeners();
  }

  Future<void> capAmountToAvailableAndRequote() async {
    final cap = availableFrom;
    if (_amount > cap && cap > 0) {
      await setAmount(cap);
    } else {
      _scheduleQuote(_amount);
    }
  }

  double _clamp(double v) {
    if (v <= 0) return 0.0;
    final cap = availableFrom;
    return (cap > 0 && v > cap) ? cap : v;
  }

  bool get hasAmount => _amount > 0;
  bool get canSwap =>
      _amount > 0 && hasEnough(_amount) && _hasEnoughXlmForFees && !_state.loading;

  // ── Quote helpers ──────────────────────────────────────────────────────────

  double? get currentMinOut {
    final est = _state.estReceive;
    if (est == null) return null;
    final v = est * (1 - _slippagePct);
    return v <= 0 ? 0.0 : v;
  }

  String buildQuoteLine(String Function(num) fmt) {
    if (_state.estReceive == null) return 'Getting live quote…';
    final recv = fmt(_state.estReceive!);
    final sl = slippagePctPercent;
    final slStr = sl % 1 == 0 ? sl.toStringAsFixed(0) : sl.toStringAsFixed(1);
    final fee = estCombinedFeeXlm;
    final feeStr = fee <= 0
        ? ''
        : ' · Fee ≈ ${fmt(fee)} XLM${_state.needsTrustline ? ' (incl. trustline)' : ''}';
    return 'Est. receive: $recv ${_state.isXlmToUsdc ? 'USDC' : 'XLM'} · Slippage: $slStr%$feeStr';
  }

  // ── Address / direction ────────────────────────────────────────────────────

  void bindToActiveWallet() => bindToAddress(_keys.accountId);

  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      _teardownStreams();
      _txFeeXlm = null;
      _set(
        _state.copyWith(
          accountId: null,
          xlmBal: 0,
          usdcBal: 0,
          estReceive: null,
          feeXlm: null,
          needsTrustline: false,
          loading: false,
          error: 'No wallet found.',
        ),
      );
      return;
    }
    if (_state.accountId == addr) return;
    _teardownStreams();
    _txFeeXlm = null;

    final home = _walletHomeVM.state;
    _set(
      _state.copyWith(
        accountId: addr,
        xlmBal: home.address == addr ? home.xlm : 0.0,
        usdcBal: home.address == addr ? home.usdc : 0.0,
        estReceive: null,
        feeXlm: null,
        needsTrustline: false,
        loading: true,
        error: '',
      ),
    );
    scheduleMicrotask(_primeAndWire);
  }

  Future<void> start() async {
    if ((_state.accountId ?? '').isEmpty) {
      _set(_state.copyWith(loading: false, error: 'No wallet found.'));
      return;
    }
    await _primeAndWire();
  }

  Future<void> setDir(SwapDir value) async {
    if (_state.dir == value) return;
    _set(
      _state.copyWith(
        dir: value,
        needsTrustline: value == SwapDir.xlmToUsdc
            ? _state.needsTrustline
            : false,
      ),
    );
    await _wireFeeStream();
    await capAmountToAvailableAndRequote();
  }

  Future<double> flipDirectionAndRequote() async {
    await setDir(_state.isXlmToUsdc ? SwapDir.usdcToXlm : SwapDir.xlmToUsdc);
    return _amount;
  }

  // ── Balances ───────────────────────────────────────────────────────────────

  Future<void> refreshBalances() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;

    final home = _walletHomeVM.state;
    if (home.address == aid) {
      _set(_state.copyWith(xlmBal: home.xlm, usdcBal: home.usdc));
    } else {
      try {
        final res = await Future.wait<double>([
          _svc.getXlmBalance(aid),
          _svc.getUsdcBalance(aid),
        ]);
        _set(_state.copyWith(xlmBal: res[0], usdcBal: res[1]));
      } catch (_) {}
    }

    try {
      final hasTl = await _svc.hasUsdcTrustline(aid);
      _set(
        _state.copyWith(needsTrustline: _state.isXlmToUsdc ? !hasTl : false),
      );
    } catch (_) {}
  }

  // ── Swap execution ─────────────────────────────────────────────────────────

  Future<String> executeSwap({
    required double amount,
    required double minOut,
  }) async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) throw StateError('Wallet not ready');

    await _svc.ensureSwapFeeConfigLoaded(refresh: true);

    final kp = await _keys.deriveKeyPair();
    final liveBreakdown = await _svc
        .getXlmBalanceBreakdown(kp.accountId)
        .catchError((_) => <String, double>{});
    final liveXlmSpendable = (liveBreakdown['spendable'] ?? _state.xlmBal)
        .toDouble();
    final liveXlmTotal = (liveBreakdown['total'] ?? liveXlmSpendable).toDouble();
    final liveXlmReserved = (liveBreakdown['reserved'] ?? 0).toDouble();
    final hasUsdcTl =
        await _svc.hasUsdcTrustline(kp.accountId).catchError((_) => true);
    final liveNeedsTrustline = !hasUsdcTl;
    final requiredXlm = _requiredXlmNonAmountBudget(
      includeTrustlineReserve: liveNeedsTrustline,
    );

    if (_state.isXlmToUsdc) {
      final totalRequiredXlm = amount + requiredXlm;
      if (totalRequiredXlm > liveXlmSpendable + _EPS) {
        throw StateError(
          'Insufficient spendable XLM for swap. '
          'Spendable: ${_floorTo(liveXlmSpendable, 7).toStringAsFixed(7)} XLM, '
          'Required: ${_floorTo(totalRequiredXlm, 7).toStringAsFixed(7)} XLM '
          '(swap ${_floorTo(amount, 7).toStringAsFixed(7)} + fees/reserve ${_floorTo(requiredXlm, 7).toStringAsFixed(7)}). '
          'Total: ${_floorTo(liveXlmTotal, 7).toStringAsFixed(7)} XLM, '
          'Reserved: ${_floorTo(liveXlmReserved, 7).toStringAsFixed(7)} XLM.',
        );
      }
    } else {
      final liveUsdc =
          await _svc.getUsdcBalance(kp.accountId).catchError((_) => _state.usdcBal);
      if (amount > liveUsdc + _EPS) {
        throw StateError(
          'Insufficient spendable USDC for swap. '
          'Spendable: ${_floorTo(liveUsdc, 7).toStringAsFixed(7)} USDC, '
          'Required: ${_floorTo(amount, 7).toStringAsFixed(7)} USDC.',
        );
      }
      if (requiredXlm > liveXlmSpendable + _EPS) {
        throw StateError(
          'Insufficient spendable XLM for swap fees. '
          'Spendable: ${_floorTo(liveXlmSpendable, 7).toStringAsFixed(7)} XLM, '
          'Required for fees/reserve: ${_floorTo(requiredXlm, 7).toStringAsFixed(7)} XLM.',
        );
      }
    }

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

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _primeAndWire() async {
    _set(_state.copyWith(loading: true, error: ''));
    try {
      await _svc.ensureSwapFeeConfigLoaded();
      await _refreshTrustlineReserveXlm();
      await refreshBalances();
      await _wireFeeStream();
      _set(_state.copyWith(loading: false, error: ''));
      if (_amount > 0) _scheduleQuote(_amount);
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to load swap: $e'));
    }
  }

  void _teardownStreams() {
    _feeSub?.cancel();
    _feeSub = null;
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    // Immediate snapshot so availableFrom is correct before the stream ticks.
    try {
      final x = await _svc.getCurrentFeeXlm();
      if ((x - txFeeXlm).abs() > _EPS) {
        _txFeeXlm = x;
        notifyListeners();
      }
    } catch (_) {}

    // 1 path-payment op + 1 extra if a trustline needs creating.
    final ops = 1 + (_state.isXlmToUsdc && _state.needsTrustline ? 1 : 0);

    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      if ((_state.feeXlm ?? 0.0) == f.totalXlm) return;
      _set(_state.copyWith(feeXlm: f.totalXlm));
      // Fee updated → availableFrom changed → re-cap _amount.
      if (_amount > 0) scheduleMicrotask(capAmountToAvailableAndRequote);
    }, onError: (_) {});
  }

  // ── Quote scheduling ───────────────────────────────────────────────────────

  Future<void> _refreshTrustlineReserveXlm() async {
    try {
      final activationMin = await _svc.getLatestReceiverActivationXlm();
      if (activationMin > 0) {
        _trustlineReserveXlm = activationMin / 2.0;
      }
    } catch (_) {}
  }

  double _requiredXlmNonAmountBudget({required bool includeTrustlineReserve}) {
    // Keep a tiny headroom to avoid boundary rounding failures on-chain.
    const double safetyBuffer = 0.0002;
    final reserve = includeTrustlineReserve ? trustlineReserveXlm : 0.0;
    return estCombinedFeeXlm + reserve + safetyBuffer;
  }

  void _scheduleQuote(double amount) {
    // Fast-path: instant update from cached rate (no network round-trip).
    final fast = _fastEstimate(amount);
    if (fast != null) {
      _set(_state.copyWith(estReceive: fast));
    } else if (amount <= 0 && _state.estReceive != null) {
      _set(_state.copyWith(estReceive: null));
    }

    _quoteTimer?.cancel();
    if (amount <= 0) return;

    final seq = ++_quoteSeq;
    _quoteTimer = Timer(_quoteDebounce, () async {
      try {
        final q = _state.isXlmToUsdc
            ? await _svc.quoteXlmToUsdc(amount)
            : await _svc.quoteUsdcToXlm(amount);
        if (seq != _quoteSeq || q == null || q <= 0) return;
        _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: amount, to: q);
        _set(_state.copyWith(estReceive: q));
      } catch (_) {}
    });
  }

  double? _fastEstimate(double amount) {
    if (amount <= 0) return null;
    final r = _cachedRate(xlmToUsdc: _state.isXlmToUsdc);
    return r == null ? _state.estReceive : _roundFrac(amount * r, 7);
  }

  // ── Solve input for desired output (AmountMode.to) ─────────────────────────

  Future<double> _solveFromForDesiredOut(double desiredOut) async {
    if (desiredOut <= 0) return 0.0;
    final cap = availableFrom;
    if (cap <= 0) return 0.0;

    // Start from cached rate or current amount as initial guess.
    final r = _cachedRate(xlmToUsdc: _state.isXlmToUsdc);
    double from = r != null
        ? desiredOut / r
        : (_amount > 0 ? _amount : desiredOut);
    if (from > cap) from = cap;

    // One real quote to calibrate the guess.
    final q = await (_state.isXlmToUsdc
        ? _svc.quoteXlmToUsdc(from)
        : _svc.quoteUsdcToXlm(from));
    final qv = q ?? 0.0;
    if (qv <= 0) return from.clamp(0, cap);

    _bumpRate(xlmToUsdc: _state.isXlmToUsdc, from: from, to: qv);

    // Proportional Newton step.
    return _floorTo((from * desiredOut / qv).clamp(0.0, cap), 7);
  }

  // ── Math utils ─────────────────────────────────────────────────────────────

  double _floor6(double v) => (v * 1e6).floor() / 1e6;

  double _floorTo(double v, int dec) {
    final s = math.pow(10, dec);
    return (v >= 0 ? (v * s).floor() / s : (v * s).ceil() / s).toDouble();
  }

  double _roundFrac(double v, int places) {
    final m = math.pow(10, places).toDouble();
    return (v * m).roundToDouble() / m;
  }
}
