import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CurrencySecureStorage {
  static const _s = FlutterSecureStorage();
  static const _kFiat = 'currency_pref_fiat_v1';
  static const _kRates = 'currency_last_good_rates_v1';

  static Future<void> saveFiat(String fiat) =>
      _s.write(key: _kFiat, value: fiat.trim().toLowerCase());
  static Future<String?> readFiat() => _s.read(key: _kFiat);
  static Future<void> clearFiat() => _s.delete(key: _kFiat);

  static Future<void> saveLastGoodRates(Map<String, dynamic> m) =>
      _s.write(key: _kRates, value: jsonEncode(m));
  static Future<Map<String, dynamic>?> readLastGoodRates() async {
    final v = await _s.read(key: _kRates);
    if (v == null || v.isEmpty) return null;
    try {
      final m = jsonDecode(v);
      return (m is Map<String, dynamic>) ? m : null;
    } catch (_) {
      return null;
    }
  }
  static Future<void> clearLastGoodRates() => _s.delete(key: _kRates);
}
