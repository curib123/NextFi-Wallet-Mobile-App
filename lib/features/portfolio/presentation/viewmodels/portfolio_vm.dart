import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/services/portfolio/portfolio_core_service.dart';
import 'package:next_fi/core/services/wallet_sync/wallet_sync_service.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_state.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';

class PortfolioVM extends ChangeNotifier {
  PortfolioVM({
    required CurrencyVM currency,
    required AssetVM assetVM,
    required WalletSyncService walletSyncService,
    PortfolioCoreService? portfolioService,
  }) : _currency = currency,
       _assetVM = assetVM,
       _portfolioService = portfolioService ?? PortfolioCoreService.I,
       _walletSyncService = walletSyncService;

  final CurrencyVM _currency;
  final AssetVM _assetVM;
  final PortfolioCoreService _portfolioService;
  final WalletSyncService _walletSyncService;

  static const Duration _appOpenCooldown = Duration(minutes: 15);

  PortfolioState _state = PortfolioState.initial();
  PortfolioState get state => _state;

  bool _disposed = false;
  int _bindEpoch = 0;
  int _loadEpoch = 0;
  String? _appVersion;
  final Map<String, Future<void>> _captureInFlight = <String, Future<void>>{};
  final Map<String, String> _lastSubmittedDedupeKeyByWallet = <String, String>{};

  void _set(PortfolioState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> bindActiveWallet({
    required String? localWalletId,
    required String? address,
    required String? label,
    WalletSnapshotTrigger? trigger,
  }) async {
    final normalizedAddress = (address ?? '').trim();
    final normalizedLabel = label?.trim();
    if (normalizedAddress.isEmpty) {
      _bindEpoch++;
      _set(
        PortfolioState.initial().copyWith(
          walletLabel: normalizedLabel,
          clearError: true,
          clearData: true,
        ),
      );
      return;
    }

    final epoch = ++_bindEpoch;
    _set(
      PortfolioState.initial().copyWith(
        activeWalletAddress: normalizedAddress,
        walletLabel: normalizedLabel,
        selectedRange: _state.selectedRange,
        loading: true,
        clearError: true,
        clearData: true,
      ),
    );

    try {
      _set(
        _state.copyWith(
          activeWalletId: normalizedAddress,
          activeWalletAddress: normalizedAddress,
          walletLabel: normalizedLabel,
          clearError: true,
        ),
      );

      await load(range: _state.selectedRange, silent: false);
      if (_disposed || epoch != _bindEpoch) return;

      if (trigger != null) {
        unawaited(
          captureSnapshot(
            trigger: trigger,
            walletAddress: normalizedAddress,
          ),
        );
      }
    } catch (error) {
      if (_disposed || epoch != _bindEpoch) return;
      _set(
        _state.copyWith(
          loading: false,
          error: 'Failed to load wallet portfolio.',
        ),
      );
      debugPrint('PortfolioVM.bindActiveWallet error: $error');
    }
  }

  Future<void> setRange(PortfolioRange range) async {
    if (_state.selectedRange == range) return;
    _set(_state.copyWith(selectedRange: range, clearError: true));
    await load(range: range, silent: false);
  }

  Future<void> load({PortfolioRange? range, bool silent = false}) async {
    final walletId = (_state.activeWalletId ?? '').trim();
    if (walletId.isEmpty) return;

    final requestEpoch = ++_loadEpoch;
    final nextRange = range ?? _state.selectedRange;
    _set(
      _state.copyWith(
        selectedRange: nextRange,
        loading: !silent,
        refreshing: silent,
        clearError: true,
      ),
    );

    try {
      final data = await _portfolioService.getWalletPortfolio(
        walletId: walletId,
        range: nextRange,
      );
      if (_disposed || requestEpoch != _loadEpoch) return;
      if ((_state.activeWalletId ?? '').trim() != walletId) return;

      _set(
        _state.copyWith(
          data: data,
          loading: false,
          refreshing: false,
          clearError: true,
          lastLoadedWalletId: walletId,
          walletLabel: data.walletLabel ?? _state.walletLabel,
          activeWalletAddress: data.walletAddress,
        ),
      );
    } catch (error) {
      if (_disposed || requestEpoch != _loadEpoch) return;
      final cached = await _walletSyncService.getCachedPortfolio(
        _state.activeWalletAddress ?? walletId,
      );
      if (cached != null) {
        _set(
          _state.copyWith(
            data: WalletPortfolioData.fromJson(cached),
            loading: false,
            refreshing: false,
            clearError: true,
            lastLoadedWalletId: walletId,
          ),
        );
        return;
      }
      _set(
        _state.copyWith(
          loading: false,
          refreshing: false,
          error: 'Portfolio unavailable',
        ),
      );
      debugPrint('PortfolioVM.load error: $error');
    }
  }

  Future<void> refreshForWallet({
    required WalletHomeState walletState,
    required WalletSnapshotTrigger trigger,
  }) async {
    await load(range: _state.selectedRange, silent: true);
    await captureSnapshot(
      trigger: trigger,
      walletAddress: walletState.address ?? _state.activeWalletAddress,
      balancesByAssetId: walletState.balancesByAssetId,
      lastBalancesAt: walletState.lastBalancesAt,
    );
    await load(range: _state.selectedRange, silent: true);
  }

  Future<void> captureSnapshot({
    required WalletSnapshotTrigger trigger,
    String? walletAddress,
    Map<String, double>? balancesByAssetId,
    DateTime? lastBalancesAt,
  }) async {
    final walletId = (_state.activeWalletId ?? '').trim();
    final activeAddress = (walletAddress ?? _state.activeWalletAddress ?? '').trim();
    if (walletId.isEmpty || activeAddress.isEmpty) return;

    final inFlightKey = '$walletId|${portfolioTriggerToApi(trigger)}';
    final existing = _captureInFlight[inFlightKey];
    if (existing != null) {
      await existing;
      return;
    }

    final future = _captureSnapshotInternal(
      walletId: walletId,
      walletAddress: activeAddress,
      trigger: trigger,
      balancesByAssetId: balancesByAssetId,
      lastBalancesAt: lastBalancesAt,
    );
    _captureInFlight[inFlightKey] = future;
    try {
      await future;
    } finally {
      _captureInFlight.remove(inFlightKey);
    }
  }

  Future<void> _captureSnapshotInternal({
    required String walletId,
    required String walletAddress,
    required WalletSnapshotTrigger trigger,
    Map<String, double>? balancesByAssetId,
    DateTime? lastBalancesAt,
  }) async {
    final assets = _snapshotAssets(
      balancesByAssetId ?? const <String, double>{},
    );
    if (assets == null) return;

    await _ensureAppVersion();
    await _currency.refreshRates(force: false);

    final now = DateTime.now();
    final data = _state.data;
    final currentSignature = _snapshotSignature(assets);
    final lastSignature = _snapshotSignatureFromState(data);
    final lastUpdated = data?.summary?.lastUpdated;

    if (trigger == WalletSnapshotTrigger.manualRefresh &&
        currentSignature == lastSignature) {
      return;
    }

    if (trigger == WalletSnapshotTrigger.appOpen &&
        lastUpdated != null &&
        currentSignature == lastSignature &&
        now.difference(lastUpdated) < _appOpenCooldown) {
      return;
    }

    if (lastBalancesAt != null &&
        now.difference(lastBalancesAt) > const Duration(minutes: 3)) {
      return;
    }

    final dedupeKey = _buildDedupeKey(
      walletId: walletId,
      trigger: trigger,
      signature: currentSignature,
      now: now,
    );
    if (_lastSubmittedDedupeKeyByWallet[walletId] == dedupeKey) {
      return;
    }

    final totalValue = assets.fold<double>(
      0.0,
      (sum, asset) => sum + asset.fiatValue,
    );

    _set(_state.copyWith(capturingSnapshot: true));
    try {
      await _portfolioService.createSnapshot(
        CreatePortfolioSnapshotRequest(
          walletId: walletId,
          walletAddress: walletAddress,
          timestamp: now,
          trigger: trigger,
          dedupeKey: dedupeKey,
          assets: assets
              .map(
                (asset) => CreatePortfolioSnapshotAssetRequest(
                  code: asset.code,
                  issuer: asset.issuer,
                  balance: asset.balance,
                  price: asset.price,
                  fiatValue: asset.fiatValue,
                  allocationPercent: asset.allocationPercent,
                ),
              )
              .toList(growable: false),
          totalValue: totalValue,
          fiatCurrency: _currency.fiatCode,
          appVersion: _appVersion,
        ),
      );
      _lastSubmittedDedupeKeyByWallet[walletId] = dedupeKey;
    } catch (error) {
      debugPrint('PortfolioVM.captureSnapshot error: $error');
    } finally {
      if (!_disposed && (_state.activeWalletId ?? '').trim() == walletId) {
        _set(_state.copyWith(capturingSnapshot: false));
      }
    }
  }

  List<_SnapshotAsset>? _snapshotAssets(Map<String, double> balancesByAssetId) {
    final supported = _assetVM.assets.where((asset) {
      final symbol = asset.symbol.trim().toUpperCase();
      return asset.enabled && (symbol == 'XLM' || symbol == 'USDC');
    }).toList(growable: false);
    if (supported.isEmpty) return null;

    final assets = <_SnapshotAsset>[];
    var totalValue = 0.0;

    for (final asset in supported) {
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      final safeBalance = balance.isFinite && balance > 0 ? balance : 0.0;
      final price = _currency.assetUnitPriceFiat(asset);
      final fiatValue = _currency.assetAmountToFiat(asset, safeBalance);
      totalValue += fiatValue;
      assets.add(
        _SnapshotAsset(
          code: asset.symbol.trim().toUpperCase(),
          issuer: asset.issuer?.trim(),
          balance: safeBalance,
          price: price.isFinite && price > 0 ? price : 0.0,
          fiatValue: fiatValue.isFinite && fiatValue > 0 ? fiatValue : 0.0,
          allocationPercent: 0.0,
        ),
      );
    }

    return assets
        .map(
          (asset) => asset.copyWith(
            allocationPercent: totalValue > 0
                ? (asset.fiatValue / totalValue) * 100
                : 0.0,
          ),
        )
        .toList(growable: false);
  }

  String _buildDedupeKey({
    required String walletId,
    required WalletSnapshotTrigger trigger,
    required String signature,
    required DateTime now,
  }) {
    final triggerKey = portfolioTriggerToApi(trigger);
    final bucketMinutes = switch (trigger) {
      WalletSnapshotTrigger.appOpen => 15,
      WalletSnapshotTrigger.manualRefresh => 1,
      WalletSnapshotTrigger.walletSwitch => 2,
      WalletSnapshotTrigger.receiveDetected => 1,
      WalletSnapshotTrigger.send => 1,
      WalletSnapshotTrigger.swap => 1,
      WalletSnapshotTrigger.claim => 1,
    };
    final minuteBucket =
        now.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    final bucket = minuteBucket ~/ bucketMinutes;
    return '$walletId|$triggerKey|$signature|$bucket';
  }

  String _snapshotSignature(List<_SnapshotAsset> assets) {
    return assets
        .map(
          (asset) =>
              '${asset.code}:${asset.balance.toStringAsFixed(7)}:${asset.fiatValue.toStringAsFixed(2)}',
        )
        .join('|');
  }

  String _snapshotSignatureFromState(WalletPortfolioData? data) {
    if (data == null || data.allocation.isEmpty) return '';
    return data.allocation
        .map(
          (asset) =>
              '${asset.code}:${asset.balance.toStringAsFixed(7)}:${asset.fiatValue.toStringAsFixed(2)}',
        )
        .join('|');
  }

  Future<void> _ensureAppVersion() async {
    if (_appVersion != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _SnapshotAsset {
  const _SnapshotAsset({
    required this.code,
    required this.issuer,
    required this.balance,
    required this.price,
    required this.fiatValue,
    required this.allocationPercent,
  });

  final String code;
  final String? issuer;
  final double balance;
  final double price;
  final double fiatValue;
  final double allocationPercent;

  _SnapshotAsset copyWith({
    double? allocationPercent,
  }) {
    return _SnapshotAsset(
      code: code,
      issuer: issuer,
      balance: balance,
      price: price,
      fiatValue: fiatValue,
      allocationPercent: allocationPercent ?? this.allocationPercent,
    );
  }
}
