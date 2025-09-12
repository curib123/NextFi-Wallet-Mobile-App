// lib/features/price_chart/viewmodel/price_chart_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/Provider/currency_vm.dart';
import '../../price_chart/model/price_chart_state.dart';

class PriceChartVM extends ChangeNotifier {
  PriceChartVM(this._currency, {PriceToken initialToken = PriceToken.xlm})
      : _token = initialToken;

  final CurrencyProvider _currency;

  PriceToken _token;
  PriceToken get token => _token;

  PriceChartRange _range = PriceChartRange.h24;
  PriceChartRange get range => _range;

  int? _hoverIndex;
  int? get hoverIndex => _hoverIndex;

  void setToken(PriceToken t) {
    if (_token == t) return;
    _token = t;
    _hoverIndex = null;
    notifyListeners();
  }

  void setRange(PriceChartRange r) {
    if (_range == r) return;
    _range = r;
    _hoverIndex = null;
    notifyListeners();
  }

  void setHoverIndex(int? i) {
    _hoverIndex = i;
    notifyListeners();
  }

  // ===== Derived data from CurrencyProvider =====

  List<double> get series {
    final isUsdc = _token == PriceToken.usdc;
    switch (_range) {
      case PriceChartRange.h24: return isUsdc ? _currency.usdcHistory24h : _currency.xlmHistory24h;
      case PriceChartRange.w1:  return isUsdc ? _currency.usdcHistory7   : _currency.xlmHistory7;
      case PriceChartRange.m1:  return isUsdc ? _currency.usdcHistory30  : _currency.xlmHistory30;
      case PriceChartRange.y1:  return isUsdc ? _currency.usdcHistory365 : _currency.xlmHistory365;
      case PriceChartRange.all: return isUsdc ? _currency.usdcHistory365 : _currency.xlmHistoryAll;
    }
  }

  double get pct {
    if (_token == PriceToken.usdc) return 0.0; // peg
    switch (_range) {
      case PriceChartRange.h24: return _currency.xlmPct24h;
      case PriceChartRange.w1:  return _currency.xlmPct7d;
      case PriceChartRange.m1:  return _currency.xlmPct30d;
      case PriceChartRange.y1:  return _currency.xlmPct1y;
      case PriceChartRange.all: return _currency.xlmPctAll;
    }
  }

  bool get isUp => pct >= 0;

  String get fiatCode => _currency.fiat.toUpperCase();
  String get fiatSym  => fiatSymbol(fiatCode);

  double get priceNow => _token == PriceToken.usdc ? _currency.usdcRate : _currency.xlmRate;

  /// When hovering: for USDC the series are already FIAT; for XLM series are USDC-per-XLM → convert via usdcRate.
  double? get hoveredPrice {
    final i = _hoverIndex;
    if (i == null) return null;
    final data = series;
    if (i < 0 || i >= data.length) return null;
    final v = data[i];
    if (_token == PriceToken.usdc) return v;
    final r = _currency.usdcRate <= 0 ? 1.0 : _currency.usdcRate;
    return v * r;
  }
}
