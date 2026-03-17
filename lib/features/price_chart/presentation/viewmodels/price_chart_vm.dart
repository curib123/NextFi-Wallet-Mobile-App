// lib/features/price_chart/view_model/price_chart_vm.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_state.dart';

class PriceChartVM extends ChangeNotifier {
  PriceChartVM(
    this._currency,
    this._assets, {
    String initialAssetKey = 'XLM',
  }) : _selectedAssetKey = initialAssetKey {
    // Relay CurrencyVM updates so the chart refreshes automatically.
    _currencyListener = () => notifyListeners();
    _currency.addListener(_currencyListener);
    _assetListener = () => notifyListeners();
    _assets.addListener(_assetListener);
  }

  final CurrencyVM _currency;
  final AssetVM _assets;
  late final VoidCallback _currencyListener;
  late final VoidCallback _assetListener;

  String _selectedAssetKey;
  String get selectedAssetKey => _selectedAssetKey;
  AssetModel? get selectedAsset =>
      _assets.findAsset(_selectedAssetKey) ??
      _assets.findAsset(_selectedAssetKey.toUpperCase());
  AssetModel? get _fallbackAsset =>
      _assets.findAsset('XLM') ?? _assets.assets.cast<AssetModel?>().firstWhere(
        (asset) => asset != null,
        orElse: () => null,
      );
  AssetModel? get activeAsset => selectedAsset ?? _fallbackAsset;
  List<AssetModel> get availableAssets =>
      _assets.assets.where(_currency.supportsAssetPricing).toList(growable: false);

  PriceChartRange _range = PriceChartRange.h24;
  PriceChartRange get range => _range;

  int? _hoverIndex;
  int? get hoverIndex => _hoverIndex;

  // Hovered price in FIAT from the *display* series
  double? _hoveredFiat;
  double? get hoveredPrice => _hoveredFiat; // keep original getter name for compatibility

  void setAsset(String assetKey) {
    final normalized = assetKey.trim();
    if (normalized.isEmpty || normalized == _selectedAssetKey) return;
    _selectedAssetKey = normalized;
    _hoverIndex = null;
    _hoveredFiat = null;
    notifyListeners();
  }

  void setRange(PriceChartRange r) {
    if (_range == r) return;
    _range = r;
    _hoverIndex = null;
    _hoveredFiat = null;
    notifyListeners();
  }

  void setHoverIndex(int? i) {
    _hoverIndex = i;
    if (i == null) {
      _hoveredFiat = null;
    } else {
      final ds = displaySeries;
      _hoveredFiat = (i >= 0 && i < ds.length) ? ds[i] : null;
    }
    notifyListeners();
  }

  // ===== Raw series from CurrencyVM (no conversion) =====

  List<double> get series {
    final asset = activeAsset;
    if (asset == null) return const [];
    switch (_range) {
      case PriceChartRange.h24:
        return _currency.assetHistory24h(asset);
      case PriceChartRange.w1:
        return _currency.assetHistory7d(asset);
      case PriceChartRange.m1:
        return _currency.assetHistory30d(asset);
      case PriceChartRange.y1:
        return _currency.assetHistory1y(asset);
      case PriceChartRange.all:
        return _currency.assetHistoryAll(asset);
    }
  }

  // Provide the same "ALL" fallback behavior your card was using
  List<double> get _seriesWithFallback {
    if (_range == PriceChartRange.all && series.length < 2) {
      final asset = activeAsset;
      if (asset == null) return const [];
      return _currency.assetHistory1y(asset);
    }
    return series;
  }

  /// Fiat display series used by header & hover (prevents double conversion).
  List<double> get displaySeries => List<double>.from(_seriesWithFallback);

  // ===== Header helpers =====

  double get pct {
    final asset = activeAsset;
    if (asset == null) return 0.0;
    switch (_range) {
      case PriceChartRange.h24:
        return asset.priceChangePercent24h;
      case PriceChartRange.w1:
        return asset.priceChangePercent7d;
      case PriceChartRange.m1:
        return asset.priceChangePercent30d;
      case PriceChartRange.y1:
        return asset.priceChangePercent1y;
      case PriceChartRange.all:
        return asset.priceChangePercent1y;
    }
  }

  bool get isUp => pct >= 0;

  String get fiatCode => _currency.fiat.toUpperCase();
  String get fiatSym => fiatSymbol(fiatCode);
  String get assetCode => activeAsset?.symbol.toUpperCase() ?? 'XLM';

  double get _liveFiatNow {
    final asset = activeAsset;
    if (asset == null) return 0.0;
    return _currency.assetUnitPriceFiat(asset);
  }

  /// Always prefer the live ticker for "current price" so it stays fresh.
  /// If live isnÃ¢â‚¬â„¢t available/finite/positive, fall back to the chart series.
  double get priceNow {
    final live = _liveFiatNow;
    if (live.isFinite && live > 0) return live;

    final ds = displaySeries;
    if (ds.isNotEmpty && ds.last.isFinite) return ds.last;
    return 0.0;
  }

  // ===== Time labels aligned with displaySeries length =====

  List<String> get timeLabels {
    final n = displaySeries.length;
    if (n <= 0) return const [];

    final now = DateTime.now();
    final window = _windowForRange(_range);
    final start = now.subtract(window);

    final fmt = _formatForRange(_range);
    final totalMs = now.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    final stepMs = n > 1 ? totalMs / (n - 1) : 0.0;

    return List<String>.generate(n, (i) {
      final t = start.add(Duration(milliseconds: (stepMs * i).round()));
      return fmt.format(t);
    });
  }

  static Duration _windowForRange(PriceChartRange r) {
    switch (r) {
      case PriceChartRange.h24: return const Duration(hours: 24);
      case PriceChartRange.w1:  return const Duration(days: 7);
      case PriceChartRange.m1:  return const Duration(days: 30);
      case PriceChartRange.y1:  return const Duration(days: 365);
      case PriceChartRange.all: return const Duration(days: 365); // adjust if you have a real "all" span
    }
  }

  static DateFormat _formatForRange(PriceChartRange r) {
    switch (r) {
      case PriceChartRange.h24: return DateFormat('h:mm a');   // hours
      case PriceChartRange.w1:  // days
      case PriceChartRange.m1:  return DateFormat('MMM d');
      case PriceChartRange.y1:  // months
      case PriceChartRange.all:return DateFormat('MMM yyyy');
    }
  }

  @override
  void dispose() {
    _currency.removeListener(_currencyListener);
    _assets.removeListener(_assetListener);
    super.dispose();
  }
}

