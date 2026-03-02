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
    // Americas
    case 'USD': return '\$';
    case 'CAD': return 'CA\$';
    case 'MXN': return 'MX\$';
    case 'BRL': return 'R\$';
    case 'ARS': return '\$';
    case 'CLP': return '\$';
    case 'COP': return '\$';
    // Europe
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'CHF': return 'Fr';
    case 'SEK': return 'kr';
    case 'NOK': return 'kr';
    case 'DKK': return 'kr';
    case 'PLN': return 'zł';
    case 'CZK': return 'Kč';
    case 'HUF': return 'Ft';
    case 'RON': return 'lei';
    case 'TRY': return '₺';
    case 'RUB': return '₽';
    case 'UAH': return '₴';
    // Asia-Pacific
    case 'JPY': return '¥';
    case 'CNY': return '¥';
    case 'HKD': return 'HK\$';
    case 'TWD': return 'NT\$';
    case 'KRW': return '₩';
    case 'SGD': return 'S\$';
    case 'MYR': return 'RM';
    case 'IDR': return 'Rp';
    case 'PHP': return '₱';
    case 'THB': return '฿';
    case 'VND': return '₫';
    case 'INR': return '₹';
    case 'PKR': return '₨';
    case 'BDT': return '৳';
    case 'AUD': return 'A\$';
    case 'NZD': return 'NZ\$';
    // Middle East / Africa
    case 'AED': return 'د.إ';
    case 'SAR': return '﷼';
    case 'QAR': return 'ر.ق';
    case 'KWD': return 'KD';
    case 'ZAR': return 'R';
    case 'NGN': return '₦';
    case 'EGP': return 'E£';
    case 'GHS': return 'GH₵';
    case 'KES': return 'KSh';
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
