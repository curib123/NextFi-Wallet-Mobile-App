import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';

/// Production-grade Asset Registry + Pricing Delta Engine
class AssetVM with ChangeNotifier {
  AssetVM(
    this.currency, {
    this.isTestnet = false,
    required this.usdcIssuer,
  }) {
    _initAssets();
    _buildLookupCache();
    _recompute();
    startRealtimeUpdates();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ CONFIG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final CurrencyVM currency;
  final bool isTestnet;
  final String usdcIssuer;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ ASSETS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final List<AssetModel> _assets = [];
  final Map<String, AssetModel> _lookup = {};

  void _initAssets() {
    _assets.addAll([
      AssetModel(
        id: 'stellar',
        name: 'Stellar Lumens',
        symbol: 'XLM',
        chain: 'stellar',
        network: isTestnet ? 'testnet' : 'mainnet',
        kind: AssetKind.native,
        isNative: true,
        assetCode: 'XLM',
        decimals: 7,
        aliases: const ['xlm', 'stellar', 'lumens'],
        tags: const ['layer1', 'featured'],
        explorer: {
          'account': _explorer('account'),
          'tx': _explorer('tx'),
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
        network: isTestnet ? 'testnet' : 'mainnet',
        kind: AssetKind.token,
        assetCode: 'USDC',
        issuer: usdcIssuer,
        decimals: 7,
        aliases: const ['usdc', 'usd coin'],
        tags: const ['stablecoin', 'featured'],
        explorer: {
          'asset':
          'https://stellar.expert/explorer/${isTestnet ? "testnet" : "public"}/asset/USDC-{issuer}',
        },
        logoUris: const [
          'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/usdc.png',
        ],
        sortOrder: 1,
      ),
    ]);
  }

  String _explorer(String type) {
    final net = isTestnet ? 'testnet' : 'public';
    return 'https://stellar.expert/explorer/$net/$type/{hash}';
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
  final Map<String, Map<String, double>> _deltaCache = {
    'xlm': {},
    'usdc': {},
  };

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
    if (v.isNaN || v.isInfinite) {
      return _deltaCache[key]?[tf] ?? 0;
    }
    _deltaCache[key]![tf] = v;
    return v;
  }

  void _recompute() {
    final deltas = {
      'xlm': {
        '24h': _pct(currency.xlmHistory24h),
        '7d': _pct(currency.xlmHistory7),
        '30d': _pct(currency.xlmHistory30),
        '1y': _pct(currency.xlmHistory365),
      },
      'usdc': {
        '24h': _pct(currency.usdcHistory24h),
        '7d': _pct(currency.usdcHistory7),
        '30d': _pct(currency.usdcHistory30),
        '1y': _pct(currency.usdcHistory365),
      },
    };

    for (int i = 0; i < _assets.length; i++) {
      final a = _assets[i];
      final k = a.symbol.toLowerCase();

      if (!deltas.containsKey(k)) continue;

      _assets[i] = a.copyWith(
        issuer: k == 'usdc' ? usdcIssuer : a.issuer,
        priceChangePercent24h: _cleanPct(k, '24h', deltas[k]!['24h']!),
        priceChangePercent7d: _cleanPct(k, '7d', deltas[k]!['7d']!),
        priceChangePercent30d: _cleanPct(k, '30d', deltas[k]!['30d']!),
        priceChangePercent1y: _cleanPct(k, '1y', deltas[k]!['1y']!),
      );
    }

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

