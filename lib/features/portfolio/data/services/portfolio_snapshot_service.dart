import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/services/portfolio/portfolio_core_service.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';

class PortfolioSnapshotService {
  PortfolioSnapshotService({
    required CurrencyVM currency,
    required AssetVM assets,
    TokenStorage? tokenStorage,
    WalletManager? walletManager,
    PortfolioCoreService? portfolioCoreService,
  }) : _currency = currency,
       _assets = assets,
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _walletManager = walletManager ?? WalletManager.I,
       _portfolioCore = portfolioCoreService ?? PortfolioCoreService.I;

  final CurrencyVM _currency;
  final AssetVM _assets;
  final TokenStorage _tokenStorage;
  final WalletManager _walletManager;
  final PortfolioCoreService _portfolioCore;

  final Set<String> _inFlightKeys = <String>{};
  final Map<String, DateTime> _lastAppOpenByWallet = <String, DateTime>{};

  PackageInfo? _packageInfo;

  Future<void> capture({
    required String walletAddress,
    required Map<String, double> balancesByAssetId,
    required WalletSnapshotTrigger trigger,
    required bool balanceChanged,
  }) async {
    final normalizedAddress = walletAddress.trim();
    if (normalizedAddress.isEmpty) return;

    final isAuthenticated = await _tokenStorage.hasTokens;
    if (!isAuthenticated) return;

    final walletId = await _walletManager.getActiveWalletBackendId();
    if (walletId == null || walletId.trim().isEmpty) return;

    if (trigger == WalletSnapshotTrigger.manualRefresh && !balanceChanged) {
      return;
    }

    if (trigger == WalletSnapshotTrigger.appOpen && !balanceChanged) {
      final last = _lastAppOpenByWallet[walletId];
      if (last != null &&
          DateTime.now().difference(last) < const Duration(minutes: 15)) {
        return;
      }
    }

    await _currency.refreshRates(force: false);
    final assets = _buildSnapshotAssets(balancesByAssetId);
    final totalValue = assets.fold<double>(
      0.0,
      (sum, asset) => sum + asset.fiatValue,
    );

    final enrichedAssets = totalValue <= 0
        ? assets
        : assets
              .map(
                (asset) => CreatePortfolioSnapshotAssetRequest(
                  code: asset.code,
                  issuer: asset.issuer,
                  balance: asset.balance,
                  price: asset.price,
                  fiatValue: asset.fiatValue,
                  allocationPercent: (asset.fiatValue / totalValue) * 100,
                ),
              )
              .toList(growable: false);

    final dedupeKey = _buildDedupeKey(
      walletId: walletId,
      trigger: trigger,
      assets: enrichedAssets,
      totalValue: totalValue,
    );

    if (!_inFlightKeys.add(dedupeKey)) return;

    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      await _portfolioCore.createSnapshot(
        CreatePortfolioSnapshotRequest(
          walletId: walletId,
          walletAddress: normalizedAddress,
          timestamp: DateTime.now(),
          trigger: trigger,
          dedupeKey: dedupeKey,
          assets: enrichedAssets,
          totalValue: totalValue,
          fiatCurrency: _currency.fiatCode,
          appVersion:
              '${_packageInfo!.version}+${_packageInfo!.buildNumber}',
        ),
      );
      if (trigger == WalletSnapshotTrigger.appOpen) {
        _lastAppOpenByWallet[walletId] = DateTime.now();
      }
    } catch (error) {
      debugPrint('PortfolioSnapshotService.capture error: $error');
    } finally {
      _inFlightKeys.remove(dedupeKey);
    }
  }

  List<CreatePortfolioSnapshotAssetRequest> _buildSnapshotAssets(
    Map<String, double> balancesByAssetId,
  ) {
    final supportedAssets = _assets.assets.where((asset) {
      final symbol = asset.symbol.trim().toUpperCase();
      return asset.enabled &&
          asset.chain.trim().toLowerCase() == 'stellar' &&
          (symbol == 'XLM' || symbol == 'USDC');
    });

    final items = <CreatePortfolioSnapshotAssetRequest>[];
    for (final asset in supportedAssets) {
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      final price = _currency.assetUnitPriceFiat(asset);
      final fiatValue = balance * price;
      items.add(
        CreatePortfolioSnapshotAssetRequest(
          code: _snapshotCode(asset),
          issuer: asset.issuer?.trim(),
          balance: balance,
          price: price,
          fiatValue: fiatValue,
          allocationPercent: 0,
        ),
      );
    }

    return items;
  }

  String _buildDedupeKey({
    required String walletId,
    required WalletSnapshotTrigger trigger,
    required List<CreatePortfolioSnapshotAssetRequest> assets,
    required double totalValue,
  }) {
    final now = DateTime.now().toUtc();
    final bucketMinutes = trigger == WalletSnapshotTrigger.appOpen ? 15 : 1;
    final bucket = now.millisecondsSinceEpoch ~/ (bucketMinutes * 60 * 1000);
    final fingerprint = [
      totalValue.toStringAsFixed(6),
      for (final asset in assets)
        '${asset.code}:${asset.issuer ?? ''}:${asset.balance.toStringAsFixed(6)}:${asset.price.toStringAsFixed(6)}'
    ].join('|');
    return '$walletId|${portfolioTriggerToApi(trigger)}|$bucket|$fingerprint';
  }

  String _snapshotCode(AssetModel asset) {
    if (asset.isNative || asset.symbol.trim().toUpperCase() == 'XLM') {
      return 'XLM';
    }
    return (asset.assetCode ?? asset.symbol).trim().toUpperCase();
  }
}
