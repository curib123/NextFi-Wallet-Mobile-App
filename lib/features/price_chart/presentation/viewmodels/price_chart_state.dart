// lib/features/price_chart/model/price_chart_state.dart
enum PriceChartRange { h24, w1, m1, y1, all }
enum PriceToken { xlm, usdc }

extension PriceChartRangeX on PriceChartRange {
  String get shortLabel {
    switch (this) {
      case PriceChartRange.h24:
        return '1D';
      case PriceChartRange.w1:
        return '1W';
      case PriceChartRange.m1:
        return '1M';
      case PriceChartRange.y1:
        return '1Y';
      case PriceChartRange.all:
        return 'ALL';
    }
  }

  String get longLabel {
    switch (this) {
      case PriceChartRange.h24:
        return '1 Day';
      case PriceChartRange.w1:
        return '1 Week';
      case PriceChartRange.m1:
        return '1 Month';
      case PriceChartRange.y1:
        return '1 Year';
      case PriceChartRange.all:
        return 'All Time';
    }
  }
}

extension PriceTokenX on PriceToken {
  String get code => this == PriceToken.usdc ? 'USDC' : 'XLM';
  static PriceToken parse(String v) =>
      v.trim().toUpperCase() == 'USDC' ? PriceToken.usdc : PriceToken.xlm;
}

String fiatSymbol(String fiat) {
  switch (fiat.toUpperCase()) {
    // Americas
    case 'USD':
      return r'$';
    case 'CAD':
      return 'CA\$';
    case 'MXN':
      return 'MX\$';
    case 'BRL':
      return 'R\$';
    case 'ARS':
      return r'$';
    case 'CLP':
      return r'$';
    case 'COP':
      return r'$';
    // Europe
    case 'EUR':
      return '\u20AC';
    case 'GBP':
      return '\u00A3';
    case 'CHF':
      return 'Fr';
    case 'SEK':
      return 'kr';
    case 'NOK':
      return 'kr';
    case 'DKK':
      return 'kr';
    case 'PLN':
      return 'z\u0142';
    case 'CZK':
      return 'K\u010D';
    case 'HUF':
      return 'Ft';
    case 'RON':
      return 'lei';
    case 'TRY':
      return '\u20BA';
    case 'RUB':
      return '\u20BD';
    case 'UAH':
      return '\u20B4';
    // Asia-Pacific
    case 'JPY':
      return '\u00A5';
    case 'CNY':
      return '\u00A5';
    case 'HKD':
      return 'HK\$';
    case 'TWD':
      return 'NT\$';
    case 'KRW':
      return '\u20A9';
    case 'SGD':
      return 'S\$';
    case 'MYR':
      return 'RM';
    case 'IDR':
      return 'Rp';
    case 'PHP':
      return '\u20B1';
    case 'THB':
      return '\u0E3F';
    case 'VND':
      return '\u20AB';
    case 'INR':
      return '\u20B9';
    case 'PKR':
      return '\u20A8';
    case 'BDT':
      return '\u09F3';
    case 'AUD':
      return 'A\$';
    case 'NZD':
      return 'NZ\$';
    // Middle East / Africa
    case 'AED':
      return '\u062F.\u0625';
    case 'SAR':
      return '\uFDFC';
    case 'QAR':
      return '\u0631.\u0642';
    case 'KWD':
      return 'KD';
    case 'ZAR':
      return 'R';
    case 'NGN':
      return '\u20A6';
    case 'EGP':
      return 'E\u00A3';
    case 'GHS':
      return 'GH\u20B5';
    case 'KES':
      return 'KSh';
    default:
      return '';
  }
}

String fmtFiat(String symbol, double v) {
  final abs = v.abs();
  final dd = abs >= 1 ? 2 : (abs >= 0.1 ? 4 : 6);
  return '$symbol${v.toStringAsFixed(dd)}';
}

String fmtPct(double v) {
  final abs = v.abs();
  final digits = abs >= 1 ? 2 : (abs >= 0.1 ? 3 : 4);
  final sign = v >= 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(digits)}%';
}
