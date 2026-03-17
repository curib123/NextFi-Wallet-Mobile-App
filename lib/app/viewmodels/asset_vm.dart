import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/services/assets/asset_catalog_service.dart';

/// Production-grade Asset Registry + Pricing Delta Engine
class AssetVM with ChangeNotifier {
  AssetVM(
    this.currency, {
    this.isTestnet = false,
    required this.usdcIssuer,
    AssetCatalogService? catalogService,
  }) {
    _catalogService = catalogService ?? AssetCatalogService();
    _initFallbackAssets();
    _buildLookupCache();
    _recompute();
    startRealtimeUpdates();
    unawaited(refreshCatalog());
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ CONFIG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final CurrencyVM currency;
  final bool isTestnet;
  final String usdcIssuer;
  late final AssetCatalogService _catalogService;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ ASSETS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final List<AssetModel> _assets = [];
  final Map<String, AssetModel> _lookup = {};

  void _initFallbackAssets() {
    _assets
      ..clear()
      ..addAll(_defaultAssets());
  }

  List<AssetModel> _defaultAssets() {
    final net = isTestnet ? 'testnet' : 'mainnet';
    final explorerNet = isTestnet ? 'testnet' : 'public';
    return [
      AssetModel(
        id: 'stellar',
        name: 'Stellar Lumens',
        symbol: 'XLM',
        chain: 'stellar',
        network: net,
        kind: AssetKind.native,
        isNative: true,
        assetCode: 'XLM',
        decimals: 7,
        aliases: const ['xlm', 'stellar', 'lumens'],
        tags: const ['layer1', 'featured'],
        externalIds: const {'coingecko': 'stellar'},
        explorer: {
          'account': 'https://stellar.expert/explorer/$explorerNet/account/{hash}',
          'tx': 'https://stellar.expert/explorer/$explorerNet/tx/{hash}',
        },
        logoUris: const [
          'https://cdn.jsdelivr.net/gh/trustwallet/assets@master/blockchains/stellar/info/logo.png',
        ],
        sortOrder: 0,
      ),
      AssetModel(
        id: 'usdc_stellar',
        name: 'USD Coin (Stellar)',
        symbol: 'USDC',
        chain: 'stellar',
        network: net,
        kind: AssetKind.token,
        assetCode: 'USDC',
        issuer: usdcIssuer,
        decimals: 7,
        aliases: const ['usdc', 'usd coin'],
        tags: const ['stablecoin', 'featured'],
        externalIds: const {'coingecko': 'usd-coin'},
        explorer: {
          'asset':
              'https://stellar.expert/explorer/$explorerNet/asset/USDC-{issuer}',
        },
        logoUris: const [
          'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
        ],
        sortOrder: 1,
      ),
    ];
  }

  Future<void> refreshCatalog() async {
    try {
      final remoteAssets = await _catalogService.fetchAssets();
      if (remoteAssets.isEmpty) return;
      _assets
        ..clear()
        ..addAll(remoteAssets);
      _buildLookupCache();
      _recompute();
      _safeNotify();
    } catch (_) {
      // Keep fallback catalog when backend is unavailable.
    }
  }

  void _buildLookupCache() {
    _lookup.clear();
    for (final a in _assets) {
      _lookup[a.id.toLowerCase()] = a;
      _lookup[a.symbol.toLowerCase()] = a;
      for (final alias in a.aliases) {
        _lookup[alias.toLowerCase()] = a;
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  bool _disposed = false;
  bool _started = false;

  StreamSubscription? _xlmSub;
  StreamSubscription? _usdcSub;
  VoidCallback? _currencyListener;

  Timer? _debounce;

  /// Cached deltas
  final Map<String, Map<String, double>> _deltaCache = {};

  List<AssetModel> _enabledSorted = [];

  List<AssetModel> get assets => _enabledSorted;

  String get vsCurrency => currency.fiat;
  bool get loading => currency.loading;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ REALTIME â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void startRealtimeUpdates() {
    if (_started) return;
    _started = true;

    _xlmSub = currency.xlmPriceStream.listen((_) => _onPriceTick());
    _usdcSub = currency.usdcPriceStream.listen((_) => _onPriceTick());

    _currencyListener = _onPriceTick;
    currency.addListener(_currencyListener!);
  }

  void stopRealtimeUpdates() {
    if (!_started) return;
    _started = false;

    _xlmSub?.cancel();
    _xlmSub = null;
    _usdcSub?.cancel();
    _usdcSub = null;

    if (_currencyListener != null) {
      currency.removeListener(_currencyListener!);
      _currencyListener = null;
    }
  }

  void _onPriceTick() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!_disposed) {
        _recompute();
        _safeNotify();
      }
    });
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ COMPUTE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  double _pct(List<double> s) {
    if (s.length < 2) return double.nan;
    final first = s.first;
    final last = s.last;
    if (first <= 0 || last <= 0) return double.nan;
    return ((last - first) / first) * 100;
  }

  double _cleanPct(String key, String tf, double v) {
    _deltaCache.putIfAbsent(key, () => <String, double>{});
    if (v.isNaN || v.isInfinite) {
      return _deltaCache[key]?[tf] ?? 0;
    }
    _deltaCache[key]![tf] = v;
    return v;
  }

  void _recompute() {
    for (int i = 0; i < _assets.length; i++) {
      final a = _assets[i];
      final k = a.symbol.toLowerCase();
      final h24 = _pct(currency.assetHistory24h(a));
      final d7 = _pct(currency.assetHistory7d(a));
      final d30 = _pct(currency.assetHistory30d(a));
      final y1 = _pct(currency.assetHistory1y(a));

      _assets[i] = a.copyWith(
        priceChangePercent24h: _cleanPct(k, '24h', h24),
        priceChangePercent7d: _cleanPct(k, '7d', d7),
        priceChangePercent30d: _cleanPct(k, '30d', d30),
        priceChangePercent1y: _cleanPct(k, '1y', y1),
      );
    }

    // Keep id/symbol/alias lookups in sync with the latest recomputed models.
    _buildLookupCache();

    _enabledSorted = _assets
        .where((a) => a.enabled)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  AssetModel? findAsset(String key) => _lookup[key.trim().toLowerCase()];

  String? issuerForSymbol(String symbol) => findAsset(symbol)?.issuer;

  String logoFor(String key) =>
      findAsset(key)?.primaryLogo ?? _lookup['xlm']!.primaryLogo;

  String? explorerUrl(
      String key, String kind, Map<String, String> vars) {
    final asset = findAsset(key);
    final tmpl = asset?.explorer[kind];
    if (tmpl == null) return null;

    var out = tmpl;
    vars.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });

    if (!vars.containsKey('issuer') && (asset?.issuer ?? '').isNotEmpty) {
      out = out.replaceAll('{issuer}', asset!.issuer!);
    }

    return out;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ LIFECYCLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    stopRealtimeUpdates();
    super.dispose();
  }
}

