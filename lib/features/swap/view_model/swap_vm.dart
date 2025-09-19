// lib/features/swap/view_model/swap_vm.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/swap/model/swap_dir.dart';
import 'package:next_fi/features/swap/model/swap_state.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar;

import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

class SwapVM extends ChangeNotifier {
  SwapVM({
    required StellarWalletServices svc,
    required SeedKeypairVM seedVM,
  })  : _svc = svc,
        _seedVM = seedVM {
    // React to active-account changes from SeedKeypairVM
    _seedListener = () {
      final aid = _seedVM.accountId;
      if ((aid ?? '') != (_state.accountId ?? '')) {
        bindToAddress(aid);
      }
    };
    _seedVM.addListener(_seedListener);

    // Warm fee stream (rewired after bind)
    scheduleMicrotask(() async {
      await _wireFeeStream();
      // Bind immediately if SeedKeypairVM already has an address
      if ((_seedVM.accountId ?? '').isNotEmpty) {
        bindToAddress(_seedVM.accountId);
      }
    });
  }

  // ── constants ──────────────────────────────────────────────────────────────
  static const double dustXlm = 1.0; // keep 1 XLM for reserve/fees
  static const double _EPS = 1e-6;

  // Slippage bounds (fractional): 0.5%..5.0%, default 1.0%
  static const double slippageMin = 0.005;
  static const double slippageMax = 0.05;

  // ── deps/internal ──────────────────────────────────────────────────────────
  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;
  late final VoidCallback _seedListener;

  StreamSubscription? _acctSub;
  StreamSubscription? _feeSub;

  bool _disposed = false;

  // ── view-facing ephemeral values (not in SwapState) ───────────────────────
  double _amount = 0.0; // user input (from-asset units)
  double get amount => _amount;

  double _slippagePct = 0.01; // fractional (e.g. 0.01 = 1%)
  double get slippagePct => _slippagePct;

  // Tx/profit fee in XLM (separate from network fee, which is in state.feeXlm)
  double? _txFeeXlm; // may be null until fetched
  double get txFeeXlm => _txFeeXlm ?? 0.0;

  // ── state (immutable data class) ──────────────────────────────────────────
  SwapState _state = const SwapState();
  SwapState get state => _state;
  void _set(SwapState s) {
    _state = s;
    _safeNotify();
  }

  // public helpers
  bool get isTestnet => _svc.isTestnet;

  // ──────────────────────────────────────────────────────────────────────────
  // Amount & Slippage API (UI calls these; VM does the work)
  // ──────────────────────────────────────────────────────────────────────────

  /// Called by UI when text field changes. Parses, clamps to available, wires fees if needed, and requotes.
  Future<void> onAmountChanged(String raw) async {
    final v = double.tryParse(raw.trim()) ?? 0.0;
    if ((v - _amount).abs() < _EPS) return;

    final cap = availableFrom;
    final clamped = v > cap && cap > 0 ? cap : (v <= 0 ? 0.0 : v);

    _amount = _floorTo(clamped, 7);
    _safeNotify(); // canSwap/labels update immediately

    await updateQuote(_amount);

    // Ensure fee stream is alive once the user interacts.
    if (_feeSub == null) {
      await _wireFeeStream();
    }
  }

  /// Programmatic set (e.g., after percent chips). Also clamps and wires fees if needed. Requotes.
  Future<void> setAmount(double value) async {
    final cap = availableFrom;
    final clamped = value > cap && cap > 0 ? cap : (value <= 0 ? 0.0 : value);
    _amount = _floorTo(clamped, 7);
    _safeNotify();
    await updateQuote(_amount);
    if (_feeSub == null) {
      await _wireFeeStream();
    }
  }

  /// Apply a percent of the available "from" balance (e.g., 0.25 = 25%).
  /// Returns the new amount for UI convenience.
  Future<double> applyPercent(double percent) async {
    final base = availableFrom;
    final v = _floorTo(base * percent, 7);
    await setAmount(v <= 0 ? 0.0 : v);
    return _amount;
  }

  /// Update slippage tolerance (fraction: 0.005..0.05).
  void setSlippagePct(double value) {
    final clamped = value.clamp(slippageMin, slippageMax).toDouble();
    if ((clamped - _slippagePct).abs() < _EPS) return;
    _slippagePct = _roundFrac(clamped, 3); // 0.1% steps
    _safeNotify(); // quote lines + confirm sheet recompute
  }

  /// Ensures the current amount does not exceed spendable "from" balance.
  /// If capped, it adjusts amount and requotes. Returns the (possibly updated) amount.
  Future<double> capAmountToAvailableAndRequote() async {
    final cap = availableFrom;
    if (_amount > cap && cap > 0) {
      await setAmount(cap);
    }
    return _amount;
  }

  // ── UI helpers so the view can "just listen" ──────────────────────────────
  bool get hasAmount => _amount > 0;
  bool get canSwap => _amount > 0 && hasEnough(_amount) && !_state.loading;

  /// Network fee estimated by Horizon (XLM).
  double get estNetworkFeeXlm => _state.feeXlm ?? 0.0;

  /// Combined fee (network + transaction/profit), all in XLM.
  double get estCombinedFeeXlm => estNetworkFeeXlm + txFeeXlm;

  /// For nicer UI copy (e.g., show "Calculating…" instead of "—").
  bool get hasFeeEstimates => estNetworkFeeXlm > 0 || txFeeXlm > 0;

  /// Current estimated min receive (pre-fee), using current slippage.
  double? get currentMinOutPreFee {
    final est = _state.estReceive;
    if (est == null) return null;
    return est * (1 - _slippagePct);
  }

  /// Current estimated min receive (after fees):
  /// - XLM→USDC: tx fee is paid in XLM, USDC out unaffected → same as pre-fee.
  /// - USDC→XLM to self: actual wallet delta is reduced by txFeeXlm.
  double? get currentMinOutAfterFees {
    final pre = currentMinOutPreFee;
    if (pre == null) return null;
    if (_state.isXlmToUsdc) return pre;
    final after = (pre - txFeeXlm);
    return after <= 0 ? 0.0 : after;
  }

  /// One-liner used by UI for the "Quote" section (pass a simple formatter).
  /// Shows est. receive + slippage + Est. transaction fee (combined).
  String buildQuoteLine(String Function(num) fmt) {
    if (_state.estReceive == null) return 'Getting live quote…';
    final recv = fmt(_state.estReceive!);
    final sl = (_slippagePct * 100);
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

  /// Bind the VM to the SeedKeypairVM’s active address.
  void bindToSeedVM() => bindToAddress(_seedVM.accountId);

  /// Bind the VM to a (possibly new) account address.
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

  /// Flip swap direction and keep the current amount valid; requote afterwards.
  /// Returns the (possibly adjusted) amount after direction flip.
  Future<double> flipDirectionAndRequote() async {
    final newDir = _state.isXlmToUsdc ? SwapDir.usdcToXlm : SwapDir.xlmToUsdc;
    await setDir(newDir);
    return await capAmountToAvailableAndRequote();
  }

  Future<void> setDir(SwapDir value) async {
    if (_state.dir == value) return;
    final needs = value == SwapDir.xlmToUsdc ? _state.needsTrustline : false;
    _set(_state.copyWith(dir: value, needsTrustline: needs));
    await _wireFeeStream(); // recompute ops & refetch fees
    await capAmountToAvailableAndRequote(); // auto-fix overshoot
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
        await updateQuote(_amount);
      }
    } catch (_) {
      // keep last
    }
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

  // ──────────────────────────────────────────────────────────────────────────
  // Swap execution (uses SeedKeypairVM to derive KeyPair ephemerally)
  // ──────────────────────────────────────────────────────────────────────────

  /// Execute swap.
  /// Optionally provide a [keyPairSupplier] (e.g., hardware signer); otherwise derives from SeedKeypairVM.
  Future<String> executeSwap({
    required double amount,
    required double minOut,
    Future<stellar.KeyPair?> Function()? keyPairSupplier,
    String? destination,
    String? memoText,
  }) async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) {
      throw StateError('Wallet not ready');
    }

    // Obtain signer
    stellar.KeyPair? kp;
    if (keyPairSupplier != null) {
      kp = await keyPairSupplier();
    }
    kp ??= await _seedVM.deriveKeyPair();

    // Execute
    final txid = _state.isXlmToUsdc
        ? await _svc.swapXlmToUsdc(
      keyPair: kp,
      sendAmountXlm: amount,
      minUsdcOut: minOut,
      destination: destination,
      memoText: memoText,
    )
        : await _svc.swapUsdcToXlm(
      keyPair: kp,
      sendAmountUsdc: amount,
      minXlmOut: minOut,
      destination: destination,
      memoText: memoText,
    );

    await refreshBalances(); // streams will tick anyway
    return txid;
  }

  @override
  void dispose() {
    _seedVM.removeListener(_seedListener);
    _teardownStreams();
    _disposed = true;
    super.dispose();
  }

  // ── internals ──────────────────────────────────────────────────────────────
  Future<void> _primeAndWire() async {
    _set(_state.copyWith(loading: true, error: ''));
    try {
      await refreshBalances();
      await _wireAccountStream();
      await _wireFeeStream(); // also fetch tx-fee
      _set(_state.copyWith(loading: false, error: ''));
      if (_amount > 0) {
        await updateQuote(_amount);
      }
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to initialize swap: $e'));
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
      // Auto-cap if user typed too much and balance changed under us
      if (_amount > 0) {
        await capAmountToAvailableAndRequote();
      }
    }, onError: (_) {
      // keep last
    });
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    // 1) Refresh *transaction/profit fee* (in XLM) so UI can show combined fee
    try {
      final x = await _svc.getCurrentFeeXlm();
      if ((x - (_txFeeXlm ?? 0.0)).abs() > _EPS) {
        _txFeeXlm = x;
        _safeNotify(); // estCombinedFeeXlm/currentMinOutAfterFees change
      }
    } catch (_) {
      // keep last known tx-fee
    }

    // 2) Recompute op-count for *network fee* estimation stream
    int ops = 1; // swap op
    int feeStroops = 0;
    try {
      feeStroops = await _svc.getCurrentFeeStroops();
    } catch (_) {}
    if (feeStroops > 0) ops += 1; // extra op: pay tx-fee in XLM
    if (_state.isXlmToUsdc && _state.needsTrustline) ops += 1; // if trustline needed

    // 3) Stream network fee estimate and update state.feeXlm continuously
    _feeSub = _svc
        .feeEstimateStream(opCount: ops, percentile: 95)
        .listen((f) {
      if ((_state.feeXlm ?? 0.0) != f.totalXlm) {
        _set(_state.copyWith(feeXlm: f.totalXlm));
      }
    }, onError: (_) {
      // keep last
    });
  }

  // ── math/utils & safe notify ──────────────────────────────────────────────
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

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }
}
