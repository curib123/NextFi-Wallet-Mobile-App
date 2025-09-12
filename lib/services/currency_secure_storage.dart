import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for currency prefs and cached rates.
class CurrencySecureStorage {
  static const _kFiatKey         = 'nextfi.currency.preferred_fiat.v1';
  static const _kRatesKey        = 'nextfi.currency.last_good_rates.v1';

  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ---------- Preferred FIAT ----------
  static Future<void> saveFiat(String fiat) =>
      _store.write(key: _kFiatKey, value: fiat.trim().toLowerCase());

  static Future<String?> readFiat() =>
      _store.read(key: _kFiatKey);

  static Future<void> clearFiat() =>
      _store.delete(key: _kFiatKey);

  // ---------- Last-good rates cache ----------
  /// Expects a JSON-serializable Map like:
  /// { "fiat": "usd", "usdcRate": 1.00, "xlmRate": 0.12, "ts": 1690000000 }
  static Future<void> saveLastGoodRates(Map<String, dynamic> data) async {
    final jsonStr = jsonEncode(data);
    await _store.write(key: _kRatesKey, value: jsonStr);
  }

  static Future<Map<String, dynamic>?> readLastGoodRates() async {
    final v = await _store.read(key: _kRatesKey);
    if (v == null || v.isEmpty) return null;
    try {
      final m = jsonDecode(v);
      return m is Map<String, dynamic> ? m : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLastGoodRates() =>
      _store.delete(key: _kRatesKey);
}
