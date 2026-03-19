import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    _buildLookupCache();
    _recompute();
    startRealtimeUpdates();
    unawaited(_hydrateCachedCatalog());
    unawaited(_loadWalletHomeVisibility());
    unawaited(refreshCatalog(retryUntilSuccess: true));
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ CONFIG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final CurrencyVM currency;
  final bool isTestnet;
  final String usdcIssuer;
  late final AssetCatalogService _catalogService;
  static const String _walletHomeVisibleAssetsKey =
      'nextfi.wallet_home.visible_assets.v1';
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ ASSETS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final List<AssetModel> _assets = [];
  final Map<String, AssetModel> _lookup = {};
  Set<String>? _walletHomeVisibleIds;
  bool _catalogRefreshRunning = false;

  Future<void> refreshCatalog({bool retryUntilSuccess = false}) async {
    if (_catalogRefreshRunning) return;
    _catalogRefreshRunning = true;

    try {
      var attempt = 0;
      while (!_disposed) {
        try {
          final remoteAssets = await _catalogService.fetchAssetsAndUpdateCache();
          _applyCatalog(remoteAssets);
          return;
        } catch (_) {
          attempt += 1;
          if (!retryUntilSuccess) return;
          final delaySeconds = attempt <= 3 ? 2 : attempt <= 6 ? 5 : 10;
          await Future<void>.delayed(Duration(seconds: delaySeconds));
        }
      }
    } finally {
      _catalogRefreshRunning = false;
    }
  }

  Future<void> _hydrateCachedCatalog() async {
    final cachedAssets = await _catalogService.readCachedAssets();
    if (_disposed || cachedAssets.isEmpty) return;
    _applyCatalog(cachedAssets, persistVisibility: false);
  }

  void _applyCatalog(
    List<AssetModel> assets, {
    bool persistVisibility = true,
  }) {
    _assets
      ..clear()
      ..addAll(assets);
    _reconcileWalletHomeVisibility();
    _buildLookupCache();
    _recompute();
    if (persistVisibility) {
      unawaited(_persistWalletHomeVisibility());
    }
    _safeNotify();
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
  List<AssetModel> get walletHomeAssets {
    final visible = _walletHomeVisibleIds;
    if (visible == null || visible.isEmpty) return _enabledSorted;
    return _enabledSorted.where((asset) => visible.contains(asset.id)).toList();
  }

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

  bool isVisibleInWalletHome(String assetId) {
    final visible = _walletHomeVisibleIds;
    if (visible == null || visible.isEmpty) return true;
    return visible.contains(assetId);
  }

  Future<void> setWalletHomeVisibility(String assetId, bool visible) async {
    final normalized = assetId.trim();
    if (normalized.isEmpty) return;

    final current = <String>{
      ...(_walletHomeVisibleIds ??
          _enabledSorted.map((asset) => asset.id)),
    };

    if (visible) {
      current.add(normalized);
    } else {
      current.remove(normalized);
    }

    _walletHomeVisibleIds = current;
    await _persistWalletHomeVisibility();
    _safeNotify();
  }

  Future<void> _loadWalletHomeVisibility() async {
    try {
      final raw = await _store.read(key: _walletHomeVisibleAssetsKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _walletHomeVisibleIds = decoded
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      _reconcileWalletHomeVisibility();
      _safeNotify();
    } catch (_) {
      // Fall back to showing all assets if local preference is unavailable.
    }
  }

  void _reconcileWalletHomeVisibility() {
    if (_enabledSorted.isEmpty && _assets.isEmpty) return;

    final enabledIds = _assets
        .where((asset) => asset.enabled)
        .map((asset) => asset.id)
        .toSet();
    if (enabledIds.isEmpty) return;

    final current = _walletHomeVisibleIds;
    if (current == null || current.isEmpty) {
      _walletHomeVisibleIds = enabledIds;
      return;
    }

    current.removeWhere((id) => !enabledIds.contains(id));
    current.addAll(enabledIds);
    _walletHomeVisibleIds = current;
  }

  Future<void> _persistWalletHomeVisibility() async {
    final visible = _walletHomeVisibleIds;
    if (visible == null || visible.isEmpty) return;
    try {
      await _store.write(
        key: _walletHomeVisibleAssetsKey,
        value: jsonEncode(visible.toList()..sort()),
      );
    } catch (_) {
      // Ignore persistence failures and keep in-memory state.
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ HELPERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  AssetModel? findAsset(String key) => _lookup[key.trim().toLowerCase()];

  String? issuerForSymbol(String symbol) => findAsset(symbol)?.issuer;

  String logoFor(String key) =>
      findAsset(key)?.primaryLogo ??
      _enabledSorted.firstOrNull?.primaryLogo ??
      '';

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

