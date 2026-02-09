import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for currency prefs and cached rates.
class CurrencySecureStorage {
  static const _kFiatKey = 'nextfi.currency.preferred_fiat.v1';
  static const _kRatesKey = 'nextfi.currency.last_good_rates.v1';
  static const _kHistoryKey = 'nextfi.currency.last_good_history.v1';

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

  /// Save preferred fiat currency (e.g., 'usd', 'eur', 'php')
  static Future<void> saveFiat(String fiat) =>
      _store.write(key: _kFiatKey, value: fiat.trim().toLowerCase());

  /// Read saved preferred fiat currency
  static Future<String?> readFiat() => _store.read(key: _kFiatKey);

  /// Clear saved fiat preference
  static Future<void> clearFiat() => _store.delete(key: _kFiatKey);

  // ---------- Last-good rates cache ----------

  /// Save last successfully fetched exchange rates.
  ///
  /// Expects a JSON-serializable Map like:
  /// ```dart
  /// {
  ///   "fiat": "usd",
  ///   "usdcRate": 1.00,
  ///   "xlmRate": 0.12,
  ///   "ts": 1690000000
  /// }
  /// ```
  static Future<void> saveLastGoodRates(Map<String, dynamic> data) async {
    try {
      final jsonStr = jsonEncode(data);
      await _store.write(key: _kRatesKey, value: jsonStr);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving rates: $e');
    }
  }

  /// Read last successfully fetched exchange rates
  static Future<Map<String, dynamic>?> readLastGoodRates() async {
    try {
      final v = await _store.read(key: _kRatesKey);
      if (v == null || v.isEmpty) return null;

      final m = jsonDecode(v);
      return m is Map<String, dynamic> ? m : null;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading rates: $e');
      return null;
    }
  }

  /// Clear cached exchange rates
  static Future<void> clearLastGoodRates() async {
    try {
      await _store.delete(key: _kRatesKey);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing rates: $e');
    }
  }

  // ---------- Last-good history cache ----------

  /// Save last successfully fetched price history.
  ///
  /// Expects a JSON-serializable Map like:
  /// ```dart
  /// {
  ///   "history": [0.10, 0.11, 0.12, ...],  // List<double>
  ///   "ts": 1690000000                      // Unix timestamp
  /// }
  /// ```
  static Future<void> saveLastGoodHistory(Map<String, dynamic> data) async {
    try {
      final jsonStr = jsonEncode(data);
      await _store.write(key: _kHistoryKey, value: jsonStr);
      debugPrint('CurrencySecureStorage: Saved history cache with ${(data['history'] as List?)?.length ?? 0} data points');
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving history: $e');
    }
  }

  /// Read last successfully fetched price history
  static Future<Map<String, dynamic>?> readLastGoodHistory() async {
    try {
      final v = await _store.read(key: _kHistoryKey);
      if (v == null || v.isEmpty) return null;

      final m = jsonDecode(v);
      if (m is Map<String, dynamic>) {
        final historyLength = (m['history'] as List?)?.length ?? 0;
        debugPrint('CurrencySecureStorage: Loaded history cache with $historyLength data points');
        return m;
      }
      return null;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading history: $e');
      return null;
    }
  }

  /// Clear cached price history
  static Future<void> clearHistory() async {
    try {
      await _store.delete(key: _kHistoryKey);
      debugPrint('CurrencySecureStorage: Cleared history cache');
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing history: $e');
    }
  }

  // ---------- Utility methods ----------

  /// Clear all cached currency data (fiat, rates, and history)
  static Future<void> clearAll() async {
    await Future.wait([
      clearFiat(),
      clearLastGoodRates(),
      clearHistory(),
    ]);
    debugPrint('CurrencySecureStorage: Cleared all currency data');
  }

  /// Check if rate cache exists
  static Future<bool> hasRateCache() async {
    final rates = await readLastGoodRates();
    return rates != null;
  }

  /// Check if history cache exists
  static Future<bool> hasHistoryCache() async {
    final history = await readLastGoodHistory();
    return history != null && (history['history'] as List?)?.isNotEmpty == true;
  }

  /// Get cache age in minutes for rates
  static Future<int?> getRateCacheAgeMinutes() async {
    final rates = await readLastGoodRates();
    if (rates == null) return null;

    final ts = rates['ts'];
    if (ts is! int) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final age = DateTime.now().difference(cachedAt);
    return age.inMinutes;
  }

  /// Get cache age in hours for history
  static Future<int?> getHistoryCacheAgeHours() async {
    final history = await readLastGoodHistory();
    if (history == null) return null;

    final ts = history['ts'];
    if (ts is! int) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final age = DateTime.now().difference(cachedAt);
    return age.inHours;
  }

  /// Get cache status summary
  static Future<Map<String, dynamic>> getCacheStatus() async {
    final hasRates = await hasRateCache();
    final hasHistory = await hasHistoryCache();
    final rateAge = await getRateCacheAgeMinutes();
    final historyAge = await getHistoryCacheAgeHours();

    return {
      'hasRateCache': hasRates,
      'hasHistoryCache': hasHistory,
      'rateCacheAgeMinutes': rateAge,
      'historyCacheAgeHours': historyAge,
    };
  }
}