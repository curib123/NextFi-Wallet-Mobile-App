import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';
import 'package:next_fi/features/swap/data/models/swap_dir.dart';
import 'package:next_fi/features/swap/presentation/viewmodels/swap_state.dart';
import 'package:next_fi/features/swap/data/models/swap_mode.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';

class SwapVM extends ChangeNotifier {
  SwapVM({
    required StellarWalletServices svc,
    required SeedKeypairVM keypairVM,
    required WalletHomeVM walletHomeVM,
    required AssetVM assetVM,
  }) : _svc = svc,
       _keys = keypairVM,
       _walletHomeVM = walletHomeVM,
       _assetVM = assetVM {
    _bootstrapAssets();
    _walletHomeVM.addListener(_onWalletHomeChanged);
    scheduleMicrotask(_wireFeeStream);
  }

  static const double _eps = 1e-6;

  static const double slippageMin = 0.005;
  static const double slippageMax = 0.05;
  static double get slippageMinPct => slippageMin * 100;
  static double get slippageMaxPct => slippageMax * 100;

  static const Duration _quoteDebounce = Duration(milliseconds: 120);
  static const double _emaAlpha = 0.35;

  final StellarWalletServices _svc;
  final SeedKeypairVM _keys;
  final WalletHomeVM _walletHomeVM;
  final AssetVM _assetVM;

  StreamSubscription? _feeSub;
  Timer? _quoteTimer;
  int _quoteSeq = 0;

  AmountMode _mode = AmountMode.from;
  AmountMode get mode => _mode;

  double _amount = 0.0;
  double _slippagePct = 0.01;
  double? _txFeeXlm;
  double _trustlineReserveXlm =
      StellarWalletServices.defaultReceiverActivationXlm / 2.0;
  String _fromAssetId = 'stellar';
  String _toAssetId = 'usdc_stellar';
  double _fromBalance = 0.0;
  double _toBalance = 0.0;
  String? _lastSuccessfulSwapTxId;
  bool _autoAddDestinationTrustline = true;
  bool _removeSourceTrustlineAfterSwap = false;
  TrustlineRemovalCheck? _sourceTrustlineRemovalCheck;
  String? _lastTrustlineActionMessage;

  double get amount => _amount;
  double get slippagePct => _slippagePct;
  double get txFeeXlm => _txFeeXlm ?? 0.0;
  double get trustlineReserveXlm => _trustlineReserveXlm;
  AssetModel get fromAsset => _resolveAsset(_fromAssetId);
  AssetModel get toAsset => _resolveAsset(_toAssetId);
  String get fromSymbol => fromAsset.symbol.toUpperCase();
  String get toSymbol => toAsset.symbol.toUpperCase();
  double get fromBalance => _fromBalance;
  double get toBalance => _toBalance;
  String? get lastSuccessfulSwapTxId => _lastSuccessfulSwapTxId;
  bool get autoAddDestinationTrustline => _autoAddDestinationTrustline;
  bool get removeSourceTrustlineAfterSwap => _removeSourceTrustlineAfterSwap;
  TrustlineRemovalCheck? get sourceTrustlineRemovalCheck =>
      _sourceTrustlineRemovalCheck;
  String? get lastTrustlineActionMessage => _lastTrustlineActionMessage;
  List<AssetModel> get swappableAssets => _assetVM.assets
      .where(
        (a) =>
            a.chain.toLowerCase() == 'stellar' &&
            (a.symbol.toUpperCase() == 'XLM' ||
                a.symbol.toUpperCase() == 'USDC'),
      )
      .toList(growable: false);

  double get slippagePctPercent => _roundFrac(_slippagePct * 100, 2);
  void setSlippagePctPercent(double pct) => setSlippagePct(pct / 100);

  final Map<String, double> _rateCache = {};
  final Map<String, DateTime> _rateUpdatedAt = {};

  void _bumpRate({
    required String fromId,
    required String toId,
    required double from,
    required double to,
  }) {
    if (from <= 0 || to <= 0) return;
    final r = to / from;
    final key = _pairKey(fromId, toId);
    final prev = _rateCache[key];
    _rateCache[key] = prev == null ? r : _ema(prev, r);
    _rateUpdatedAt[key] = DateTime.now();
  }

  double? _cachedRate({required String fromId, required String toId}) {
    final key = _pairKey(fromId, toId);
    final r = _rateCache[key];
    if (r == null) return null;
    final updatedAt = _rateUpdatedAt[key];
    final stale = updatedAt == null
        ? true
        : DateTime.now().difference(updatedAt) > const Duration(seconds: 30);
    return stale ? null : r;
  }

  String _pairKey(String fromId, String toId) => '$fromId->$toId';

  double _ema(double prev, double next) => prev + _emaAlpha * (next - prev);

  SwapState _state = const SwapState();
  SwapState get state => _state;

  void _set(SwapState s, {bool notify = true}) {
    _state = s;
    if (notify) notifyListeners();
  }

  bool get isTestnet => _svc.isTestnet;

  AssetModel _resolveAsset(String id) =>
      _assetVM.findAsset(id) ??
      _assetVM.findAsset('xlm') ??
      swappableAssets.first;

  void _bootstrapAssets() {
    final assets = swappableAssets;
    if (assets.isEmpty) return;

    AssetModel? xlm;
    AssetModel? usdc;
    for (final asset in assets) {
      final symbol = asset.symbol.toUpperCase();
      if (xlm == null && symbol == 'XLM') xlm = asset;
      if (usdc == null && symbol == 'USDC') usdc = asset;
    }

    final from = xlm ?? assets.first;
    final to =
        usdc ?? assets.firstWhere((a) => a.id != from.id, orElse: () => from);

    _fromAssetId = from.id;
    _toAssetId = to.id;
  }

  Asset _toStellarAsset(AssetModel model) {
    if (model.isNative || model.symbol.toUpperCase() == 'XLM') {
      return Asset.NATIVE;
    }
    final code = (model.assetCode ?? model.symbol).trim();
    final issuer = (model.issuer ?? '').trim();
    if (code.isEmpty || issuer.isEmpty) {
      throw StateError('Asset ${model.symbol} is missing Stellar metadata.');
    }
    return code.length <= 4
        ? AssetTypeCreditAlphaNum4(code, issuer)
        : AssetTypeCreditAlphaNum12(code, issuer);
  }

  bool get _isSendingNative => fromAsset.isNative || fromSymbol == 'XLM';
  bool get _isReceivingNative => toAsset.isNative || toSymbol == 'XLM';
  bool get destinationHasTrustline =>
      _isReceivingNative || !_state.needsTrustline;
  bool get showDestinationTrustlineSection => !_isReceivingNative;
  bool get showSourceTrustlineRemovalSection =>
      !_isSendingNative && (_sourceTrustlineRemovalCheck?.hasTrustline ?? false);
  bool get willAutoAddDestinationTrustline =>
      !_isReceivingNative &&
      _state.needsTrustline &&
      _autoAddDestinationTrustline;

  String get destinationTrustlineHint {
    if (_isReceivingNative) {
      return 'XLM is native on Stellar and does not need a trustline.';
    }
    if (destinationHasTrustline) {
      return '$toSymbol trustline is already active on this wallet.';
    }
    if (_autoAddDestinationTrustline) {
      return 'This swap will auto-add the $toSymbol trustline and reserve about ${_floorTo(trustlineReserveXlm, 2).toStringAsFixed(2)} XLM.';
    }
    return 'Turn on auto-add trustline to receive $toSymbol on this wallet.';
  }

  String? get sourceTrustlineRemovalHint {
    if (!showSourceTrustlineRemovalSection) return null;
    final check = _sourceTrustlineRemovalCheck;
    if (check == null) {
      return 'Checking whether this trustline can be removed safely after the swap.';
    }
    if (!_removeSourceTrustlineAfterSwap) {
      return 'Optional: remove the empty $fromSymbol trustline after swapping out the full balance.';
    }
    if (check.sellingLiabilities > _eps) {
      return check.blockingReason ??
          'This trustline still has open liabilities and cannot be removed yet.';
    }
    if (_amount <= 0) {
      return 'Enter a $fromSymbol amount before removing the trustline after swap.';
    }
    if (_amount + _eps < check.availableBalance) {
      return 'Swap the full available $fromSymbol balance to remove this trustline after the swap.';
    }
    return 'After the swap clears the $fromSymbol balance, the wallet will remove the empty trustline automatically.';
  }

  String? get trustlineValidationMessage {
    if (showDestinationTrustlineSection &&
        _state.needsTrustline &&
        !_autoAddDestinationTrustline) {
      return 'Enable auto-add trustline to receive $toSymbol on this wallet.';
    }
    if (_removeSourceTrustlineAfterSwap) {
      final hint = sourceTrustlineRemovalHint;
      if (hint != null &&
          (hint.startsWith('Checking whether') ||
              hint.startsWith('Enter a ') ||
              hint.startsWith('Swap the full') ||
              hint.startsWith('This trustline still'))) {
        return hint;
      }
    }
    return null;
  }

  void _onWalletHomeChanged() {
    if ((_state.accountId ?? '').isEmpty) return;
    scheduleMicrotask(() async {
      await refreshBalances();
      if (_amount > 0) {
        await capAmountToAvailableAndRequote();
      }
    });
  }

  double get estNetworkFeeXlm => _state.feeXlm ?? 0.0;
  double get estCombinedFeeXlm => estNetworkFeeXlm + txFeeXlm;
  bool get hasFeeEstimates => estNetworkFeeXlm > 0 || txFeeXlm > 0;

  double get availableFrom {
    if (_isSendingNative) {
      final kept = _requiredXlmNonAmountBudget(
        includeTrustlineReserve:
            _state.needsTrustline && _autoAddDestinationTrustline,
      );
      return _floor6((_state.xlmBal - kept).clamp(0.0, double.infinity));
    }
    return _floor6(_fromBalance);
  }

  bool hasEnough(double amount) => amount > 0 && amount <= availableFrom + _eps;
  bool get _hasEnoughXlmForFees =>
      _state.xlmBal >=
      _requiredXlmNonAmountBudget(
            includeTrustlineReserve:
                _state.needsTrustline && _autoAddDestinationTrustline,
          ) -
          _eps;

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
      if ((clamped - _amount).abs() < _eps) {
        _scheduleQuote(_amount);
        return;
      }
      _amount = _floorTo(clamped, 7);
      notifyListeners();
      _scheduleQuote(_amount);
      return;
    }

    final clamped = _clamp(parsed);
    if ((clamped - _amount).abs() < _eps) return;
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
    if ((c - _slippagePct).abs() < _eps) return;
    _slippagePct = _roundFrac(c, 4);
    notifyListeners();
  }

  void setAutoAddDestinationTrustline(bool value) {
    if (_autoAddDestinationTrustline == value) return;
    _autoAddDestinationTrustline = value;
    notifyListeners();
  }

  void setRemoveSourceTrustlineAfterSwap(bool value) {
    if (_removeSourceTrustlineAfterSwap == value) return;
    _removeSourceTrustlineAfterSwap = value;
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
      _amount > 0 &&
      hasEnough(_amount) &&
      _hasEnoughXlmForFees &&
      trustlineValidationMessage == null &&
      !_state.loading;

  double? get currentMinOut {
    final est = _state.estReceive;
    if (est == null) return null;
    final v = est * (1 - _slippagePct);
    return v <= 0 ? 0.0 : v;
  }

  String buildQuoteLine(String Function(num) fmt) {
    if (_state.estReceive == null) return 'Getting live quote...';
    final recv = fmt(_state.estReceive!);
    final sl = slippagePctPercent;
    final slStr = sl % 1 == 0 ? sl.toStringAsFixed(0) : sl.toStringAsFixed(1);
    final fee = estCombinedFeeXlm;
    final feeStr = fee <= 0
        ? ''
        : ' | Fee ~ ${fmt(fee)} XLM${_state.needsTrustline && _autoAddDestinationTrustline ? ' (incl. trustline)' : ''}';
    return 'Est. receive: $recv $toSymbol | Slippage: $slStr%$feeStr';
  }

  void bindToActiveWallet() => bindToAddress(_keys.accountId);

  void bindToAddress(String? newAddr) {
    final addr = (newAddr ?? '').trim();
    if (addr.isEmpty) {
      _teardownStreams();
      _txFeeXlm = null;
      _fromBalance = 0.0;
      _toBalance = 0.0;
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
    _fromBalance = _balanceFromHome(home, _fromAssetId) ?? 0.0;
    _toBalance = _balanceFromHome(home, _toAssetId) ?? 0.0;
    _set(
      _state.copyWith(
        accountId: addr,
        xlmBal: home.address == addr ? home.xlm : 0.0,
        usdcBal: _fromBalance,
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
    final xlm = swappableAssets.firstWhere(
      (a) => a.symbol.toUpperCase() == 'XLM',
      orElse: () => fromAsset,
    );
    final usdc = swappableAssets.firstWhere(
      (a) => a.symbol.toUpperCase() == 'USDC',
      orElse: () => toAsset.id != xlm.id ? toAsset : fromAsset,
    );
    if (value == SwapDir.xlmToUsdc) {
      await _setAssets(from: xlm, to: usdc);
    } else {
      await _setAssets(from: usdc, to: xlm);
    }
  }

  Future<double> flipDirectionAndRequote() async {
    await _setAssets(from: toAsset, to: fromAsset);
    return _amount;
  }

  Future<void> selectFromAsset(AssetModel asset) async {
    if (!_isSupportedAsset(asset) || asset.id == _fromAssetId) return;
    await _setAssets(
      from: asset,
      to: asset.id == _toAssetId ? fromAsset : toAsset,
    );
  }

  Future<void> selectToAsset(AssetModel asset) async {
    if (!_isSupportedAsset(asset) || asset.id == _toAssetId) return;
    await _setAssets(
      from: asset.id == _fromAssetId ? toAsset : fromAsset,
      to: asset,
    );
  }

  Future<void> _setAssets({
    required AssetModel from,
    required AssetModel to,
  }) async {
    if (!_isSupportedPair(from, to)) {
      final xlm = swappableAssets.firstWhere(
        (asset) => asset.symbol.toUpperCase() == 'XLM',
        orElse: () => fromAsset,
      );
      final usdc = swappableAssets.firstWhere(
        (asset) => asset.symbol.toUpperCase() == 'USDC',
        orElse: () => toAsset,
      );
      from = from.symbol.toUpperCase() == 'USDC' ? usdc : xlm;
      to = from.id == usdc.id ? xlm : usdc;
    }
    if (from.id == to.id) return;
    _fromAssetId = from.id;
    _toAssetId = to.id;
    _autoAddDestinationTrustline = true;
    _removeSourceTrustlineAfterSwap = false;
    _sourceTrustlineRemovalCheck = null;
    _lastTrustlineActionMessage = null;
    _quoteSeq++;
    _set(_state.copyWith(estReceive: null));
    await refreshBalances();
    await _wireFeeStream();
    await capAmountToAvailableAndRequote();
  }

  bool _isSupportedAsset(AssetModel asset) {
    final symbol = asset.symbol.trim().toUpperCase();
    return symbol == 'XLM' || symbol == 'USDC';
  }

  bool _isSupportedPair(AssetModel from, AssetModel to) {
    if (!_isSupportedAsset(from) || !_isSupportedAsset(to)) return false;
    return from.symbol.toUpperCase() != to.symbol.toUpperCase();
  }

  double? _balanceFromHome(dynamic home, String assetId) {
    final asset = _resolveAsset(assetId);
    final symbol = asset.symbol.toUpperCase();
    if (symbol == 'XLM') return home.xlm as double;
    if (symbol == 'USDC') return home.usdc as double;
    return null;
  }

  Future<void> refreshBalances() async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) return;

    final home = _walletHomeVM.state;
    double? xlmBal = home.address == aid ? home.xlm : null;
    double? fromBal = _balanceFromHome(home, _fromAssetId);
    double? toBal = _balanceFromHome(home, _toAssetId);

    try {
      xlmBal ??= await _svc.getXlmBalance(aid);
      fromBal ??= await _svc.getAssetBalance(aid, _toStellarAsset(fromAsset));
      toBal ??= await _svc.getAssetBalance(aid, _toStellarAsset(toAsset));
    } catch (_) {}

    _fromBalance = fromBal ?? _fromBalance;
    _toBalance = toBal ?? _toBalance;

    bool needsTrustline = false;
    if (!_isReceivingNative) {
      try {
        needsTrustline = !await _svc.hasTrustline(
          aid,
          _toStellarAsset(toAsset),
        );
      } catch (_) {}
    }

    TrustlineRemovalCheck? sourceRemovalCheck;
    if (!_isSendingNative) {
      try {
        sourceRemovalCheck = await _svc.getTrustlineRemovalCheck(
          accountId: aid,
          asset: _toStellarAsset(fromAsset),
        );
      } catch (_) {}
    }
    _sourceTrustlineRemovalCheck = sourceRemovalCheck;

    _set(
      _state.copyWith(
        xlmBal: xlmBal ?? _state.xlmBal,
        usdcBal: _fromBalance,
        needsTrustline: needsTrustline,
      ),
    );
    notifyListeners();
  }

  Future<String> executeSwap({
    required double amount,
    required double minOut,
  }) async {
    final aid = _state.accountId;
    if (aid == null || aid.isEmpty) {
      throw StellarWalletError(
        'Wallet not ready',
        advice: 'Open or create a wallet, then try the swap again.',
        code: 'SWAP_WALLET_NOT_READY',
      );
    }
    if (amount <= 0) {
      throw StellarWalletError(
        'Enter an amount greater than 0',
        advice: 'Try entering a valid $fromSymbol amount to swap.',
        code: 'SWAP_INVALID_AMOUNT',
      );
    }
    if (minOut <= 0) {
      throw StellarWalletError(
        'Minimum receive amount must be greater than 0',
        advice: 'Wait for a live quote, then confirm the swap again.',
        code: 'SWAP_INVALID_MIN_OUT',
      );
    }
    if (fromAsset.id == toAsset.id) {
      throw StellarWalletError(
        'Choose two different assets to swap',
        advice: 'Pick a different asset to receive.',
        code: 'SWAP_SAME_ASSET',
      );
    }

    await _svc.ensureSwapFeeConfigLoaded(refresh: true);
    _lastTrustlineActionMessage = null;

    final kp = await _keys.deriveKeyPair();
    final liveBreakdown = await _svc
        .getXlmBalanceBreakdown(kp.accountId)
        .catchError((_) => <String, double>{});
    final liveXlmSpendable = (liveBreakdown['spendable'] ?? _state.xlmBal)
        .toDouble();
    final liveXlmTotal = (liveBreakdown['total'] ?? liveXlmSpendable)
        .toDouble();
    final liveXlmReserved = (liveBreakdown['reserved'] ?? 0).toDouble();
    final liveNeedsTrustline =
        !_isReceivingNative &&
        !await _svc
            .hasTrustline(kp.accountId, _toStellarAsset(toAsset))
            .catchError((_) => true);
    final requiredXlm = _requiredXlmNonAmountBudget(
      includeTrustlineReserve: liveNeedsTrustline,
    );

    if (!_isReceivingNative &&
        liveNeedsTrustline &&
        !_autoAddDestinationTrustline) {
      throw StellarWalletError(
        'A $toSymbol trustline is required before you can receive this asset',
        advice:
            'Enable auto-add trustline or switch the asset you want to receive.',
        code: 'SWAP_TRUSTLINE_REQUIRED',
      );
    }

    final trustlineValidation = trustlineValidationMessage;
    if (trustlineValidation != null &&
        !trustlineValidation.startsWith('Enable auto-add')) {
      throw StellarWalletError(
        'Trustline action needs attention',
        advice: trustlineValidation,
        code: 'SWAP_TRUSTLINE_ACTION_BLOCKED',
      );
    }

    if (_isSendingNative) {
      final totalRequiredXlm = amount + requiredXlm;
      if (totalRequiredXlm > liveXlmSpendable + _eps) {
        final missing = totalRequiredXlm - liveXlmSpendable;
        throw StellarWalletError(
          'Not enough spendable XLM for this swap',
          technicalDetails:
              'Spendable XLM: ${_floorTo(liveXlmSpendable, 7).toStringAsFixed(7)} | '
              'Required XLM: ${_floorTo(totalRequiredXlm, 7).toStringAsFixed(7)} | '
              'Total XLM: ${_floorTo(liveXlmTotal, 7).toStringAsFixed(7)} | '
              'Reserved XLM: ${_floorTo(liveXlmReserved, 7).toStringAsFixed(7)}',
          advice:
              'You need ${_floorTo(missing, 7).toStringAsFixed(7)} more spendable XLM to cover the swap amount, fees, and any trustline reserve.',
          code: 'SWAP_INSUFFICIENT_XLM',
        );
      }
    } else {
      final liveFrom = await _svc
          .getAssetBalance(kp.accountId, _toStellarAsset(fromAsset))
          .catchError((_) => _fromBalance);
      if (amount > liveFrom + _eps) {
        final missing = amount - liveFrom;
        throw StellarWalletError(
          'Not enough $fromSymbol to complete this swap',
          technicalDetails:
              'Spendable $fromSymbol: ${_floorTo(liveFrom, 7).toStringAsFixed(7)} | '
              'Required: ${_floorTo(amount, 7).toStringAsFixed(7)}',
          advice:
              'You need ${_floorTo(missing, 7).toStringAsFixed(7)} more $fromSymbol or a smaller swap amount.',
          code: 'SWAP_INSUFFICIENT_SOURCE',
        );
      }
      if (requiredXlm > liveXlmSpendable + _eps) {
        final missing = requiredXlm - liveXlmSpendable;
        throw StellarWalletError(
          liveNeedsTrustline
              ? 'Not enough XLM to cover swap fees and auto-add the ${toSymbol.toUpperCase()} trustline'
              : 'Not enough XLM to cover swap fees',
          technicalDetails:
              'Spendable XLM: ${_floorTo(liveXlmSpendable, 7).toStringAsFixed(7)} | '
              'Required XLM: ${_floorTo(requiredXlm, 7).toStringAsFixed(7)}',
          advice:
              'Add ${_floorTo(missing, 7).toStringAsFixed(7)} more XLM so the swap can complete cleanly.',
          code: 'SWAP_INSUFFICIENT_XLM_FEES',
        );
      }
    }

    final txid = await _svc.swapAssets(
      keyPair: kp,
      sending: _toStellarAsset(fromAsset),
      receiving: _toStellarAsset(toAsset),
      sendAmount: amount,
      minOut: minOut,
    );

    _lastSuccessfulSwapTxId = txid;
    await _walletHomeVM.refresh(force: true);
    if (_removeSourceTrustlineAfterSwap && !_isSendingNative) {
      _lastTrustlineActionMessage = await _removeSourceTrustlineIfPossible(
        keyPair: kp,
        asset: fromAsset,
      );
      _removeSourceTrustlineAfterSwap = false;
      notifyListeners();
    }
    return txid;
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _teardownStreams();
    _walletHomeVM.removeListener(_onWalletHomeChanged);
    super.dispose();
  }

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
      _set(_state.copyWith(loading: false, error: _friendlyBootError(e)));
    }
  }

  String _friendlyBootError(Object error) {
    final raw = error.toString().trim();
    final normalized = raw.toLowerCase();

    if (normalized.contains('no wallet found')) {
      return 'No wallet found.';
    }

    if (normalized.contains('busy') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('503') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('socketexception') ||
        normalized.contains('connection') ||
        normalized.contains('network')) {
      return 'The Stellar services are busy right now. Wait a moment, then try again.';
    }

    return 'Unable to load swap right now. Please try again in a moment.';
  }

  void _teardownStreams() {
    _feeSub?.cancel();
    _feeSub = null;
  }

  Future<void> _wireFeeStream() async {
    _feeSub?.cancel();

    try {
      final x = await _svc.getCurrentFeeXlm();
      if ((x - txFeeXlm).abs() > _eps) {
        _txFeeXlm = x;
        notifyListeners();
      }
    } catch (_) {}

    final ops = 1 + (_state.needsTrustline ? 1 : 0);

    _feeSub = _svc.feeEstimateStream(opCount: ops, percentile: 95).listen((f) {
      if ((_state.feeXlm ?? 0.0) == f.totalXlm) return;
      _set(_state.copyWith(feeXlm: f.totalXlm));
      if (_amount > 0) scheduleMicrotask(capAmountToAvailableAndRequote);
    }, onError: (_) {});
  }

  Future<void> _refreshTrustlineReserveXlm() async {
    try {
      final activationMin = await _svc.getLatestReceiverActivationXlm();
      if (activationMin > 0) {
        _trustlineReserveXlm = activationMin / 2.0;
      }
    } catch (_) {}
  }

  double _requiredXlmNonAmountBudget({required bool includeTrustlineReserve}) {
    const double safetyBuffer = 0.0002;
    final reserve = includeTrustlineReserve ? trustlineReserveXlm : 0.0;
    return estCombinedFeeXlm + reserve + safetyBuffer;
  }

  Future<String?> _removeSourceTrustlineIfPossible({
    required KeyPair keyPair,
    required AssetModel asset,
  }) async {
    try {
      final stellarAsset = _toStellarAsset(asset);
      final check = await _svc.getTrustlineRemovalCheck(
        accountId: keyPair.accountId,
        asset: stellarAsset,
      );
      if (!check.hasTrustline) {
        return '$fromSymbol trustline is already inactive.';
      }
      if (!check.canRemove) {
        return check.blockingReason ??
            'Swap completed, but the $fromSymbol trustline could not be removed.';
      }
      await _svc.removeTrustline(keyPair: keyPair, asset: stellarAsset);
      await _walletHomeVM.refresh(force: true);
      return '$fromSymbol trustline removed and reserve released.';
    } catch (_) {
      return 'Swap completed, but the $fromSymbol trustline could not be removed.';
    }
  }

  void _scheduleQuote(double amount) {
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
        final q = await _svc.quoteStrictSend(
          sourceAsset: _toStellarAsset(fromAsset),
          sourceAmount: amount.toStringAsFixed(7),
          destinationAssets: [_toStellarAsset(toAsset)],
        );
        if (seq != _quoteSeq || q == null || q <= 0) return;
        _bumpRate(fromId: _fromAssetId, toId: _toAssetId, from: amount, to: q);
        _set(_state.copyWith(estReceive: q));
      } catch (_) {}
    });
  }

  double? _fastEstimate(double amount) {
    if (amount <= 0) return null;
    final r = _cachedRate(fromId: _fromAssetId, toId: _toAssetId);
    return r == null ? _state.estReceive : _roundFrac(amount * r, 7);
  }

  Future<double> _solveFromForDesiredOut(double desiredOut) async {
    if (desiredOut <= 0) return 0.0;
    final cap = availableFrom;
    if (cap <= 0) return 0.0;

    final r = _cachedRate(fromId: _fromAssetId, toId: _toAssetId);
    double from = r != null
        ? desiredOut / r
        : (_amount > 0 ? _amount : desiredOut);
    if (from > cap) from = cap;

    final q = await _svc.quoteStrictSend(
      sourceAsset: _toStellarAsset(fromAsset),
      sourceAmount: from.toStringAsFixed(7),
      destinationAssets: [_toStellarAsset(toAsset)],
    );
    final qv = q ?? 0.0;
    if (qv <= 0) return from.clamp(0, cap);

    _bumpRate(fromId: _fromAssetId, toId: _toAssetId, from: from, to: qv);

    return _floorTo((from * desiredOut / qv).clamp(0.0, cap), 7);
  }

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
