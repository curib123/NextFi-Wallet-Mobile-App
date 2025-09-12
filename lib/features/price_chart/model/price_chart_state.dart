// lib/features/price_chart/model/price_chart_state.dart
enum PriceChartRange { h24, w1, m1, y1, all }
enum PriceToken { xlm, usdc }

extension PriceTokenX on PriceToken {
  String get code => this == PriceToken.usdc ? 'USDC' : 'XLM';
  static PriceToken parse(String v) =>
      v.trim().toUpperCase() == 'USDC' ? PriceToken.usdc : PriceToken.xlm;
}

String fiatSymbol(String fiat) {
  switch (fiat.toUpperCase()) {
    case 'USD': return '\$';
    case 'PHP': return '₱';
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'JPY': return '¥';
    default:    return '';
  }
}

String fmtFiat(String symbol, double v) {
  // keep the same logic you had, simplified here:
  final abs = v.abs();
  int dd = abs >= 1 ? 2 : (abs >= 0.1 ? 4 : 6);
  return "${symbol}${v.toStringAsFixed(dd)}";
}

String fmtPct(double v) {
  final abs = v.abs();
  final digits = abs >= 1 ? 2 : (abs >= 0.1 ? 3 : 4);
  final sign = v >= 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(digits)}%';
}
