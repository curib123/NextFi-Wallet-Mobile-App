// lib/features/price_chart/view_model/price_chart_vm.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_state.dart';

class PriceChartVM extends ChangeNotifier {
  PriceChartVM(this._currency, {PriceToken initialToken = PriceToken.xlm})
      : _token = initialToken {
    // Relay CurrencyVM updates so the chart refreshes automatically.
    _currencyListener = () => notifyListeners();
    _currency.addListener(_currencyListener);
  }

  final CurrencyVM _currency;
  late final VoidCallback _currencyListener;

  PriceToken _token;
  PriceToken get token => _token;

  PriceChartRange _range = PriceChartRange.h24;
  PriceChartRange get range => _range;

  int? _hoverIndex;
  int? get hoverIndex => _hoverIndex;

  // Hovered price in FIAT from the *display* series
  double? _hoveredFiat;
  double? get hoveredPrice => _hoveredFiat; // keep original getter name for compatibility

  void setToken(PriceToken t) {
    if (_token == t) return;
    _token = t;
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
    final isUsdc = _token == PriceToken.usdc;
    switch (_range) {
      case PriceChartRange.h24:
        return isUsdc ? _currency.usdcHistory24h : _currency.xlmHistory24h;
      case PriceChartRange.w1:
        return isUsdc ? _currency.usdcHistory7 : _currency.xlmHistory7;
      case PriceChartRange.m1:
        return isUsdc ? _currency.usdcHistory30 : _currency.xlmHistory30;
      case PriceChartRange.y1:
        return isUsdc ? _currency.usdcHistory365 : _currency.xlmHistory365;
      case PriceChartRange.all:
        return isUsdc ? _currency.usdcHistory365 : _currency.xlmHistoryAll;
    }
  }

  // Provide the same "ALL" fallback behavior your card was using
  List<double> get _seriesWithFallback {
    if (_range == PriceChartRange.all && series.length < 2) {
      return _token == PriceToken.usdc ? _currency.usdcHistory365 : _currency.xlmHistory365;
    }
    return series;
  }

  // ===== Display series in FIAT (single source of truth for UI values) =====

  /// Heuristic: if XLM raw points look already in fiat (close to xlmRate), don't convert.
  /// Else, if (raw * usdcRate) is closer to xlmRate, convert using usdcRate.
  bool _shouldConvertXlmToFiat(List<double> raw) {
    if (raw.isEmpty) return false;
    final last = raw.last;
    final xlmRate = _currency.xlmRate;   // current XLM price in selected fiat
    final usdToFiat = _currency.usdcRate; // 1 USDC in selected fiat
    if (xlmRate <= 0 || usdToFiat <= 0) return false;

    final diffNoConv = (last - xlmRate).abs();
    final diffConv   = (last * usdToFiat - xlmRate).abs();
    return diffConv < diffNoConv;
  }

  /// Fiat display series used by header & hover (prevents double conversion).
  List<double> get displaySeries {
    final raw = _seriesWithFallback;
    if (raw.isEmpty) return const [];

    if (_token == PriceToken.usdc) {
      // USDC histories are ~peg in selected fiat already
      return List<double>.from(raw);
    }

    // XLM: decide if raw is USDC-quoted (needs conversion) or already in fiat
    if (_shouldConvertXlmToFiat(raw)) {
      final r = _currency.usdcRate <= 0 ? 1.0 : _currency.usdcRate;
      return raw.map((v) => v * r).toList();
    } else {
      return List<double>.from(raw);
    }
  }

  // ===== Header helpers =====

  double get pct {
    if (_token == PriceToken.usdc) return 0.0; // peg
    switch (_range) {
      case PriceChartRange.h24:
        return _currency.xlmPct24h;
      case PriceChartRange.w1:
        return _currency.xlmPct7d;
      case PriceChartRange.m1:
        return _currency.xlmPct30d;
      case PriceChartRange.y1:
        return _currency.xlmPct1y;
      case PriceChartRange.all:
        return _currency.xlmPctAll;
    }
  }

  bool get isUp => pct >= 0;

  String get fiatCode => _currency.fiat.toUpperCase();
  String get fiatSym => fiatSymbol(fiatCode);

  double get _liveFiatNow =>
      _token == PriceToken.usdc ? _currency.usdcRate : _currency.xlmRate;

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
    super.dispose();
  }
}

