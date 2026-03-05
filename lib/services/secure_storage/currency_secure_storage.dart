import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for currency prefs and cached rates.
///
/// ⚠️ Android WARNING: [AndroidOptions.resetOnError] is set to `true`.
/// This wipes the ENTIRE EncryptedSharedPreferences store on decryption
/// failure — not just currency keys. Ensure all other secrets stored in
/// this store are re-derivable (e.g. from biometric re-auth) on app restart.
class CurrencySecureStorage {
  static const _kFiatKey = 'nextfi.currency.preferred_fiat.v1';
  static const _kRatesKey = 'nextfi.currency.last_good_rates.v1';
  static const _kHistoryKey = 'nextfi.currency.last_good_history.v1';

  /// Maximum allowed payload size to guard against memory exhaustion
  /// from oversized remote payloads or corrupted data.
  static const int _kMaxValueBytes = 512 * 1024; // 512 KB

  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true, // ⚠️ Wipes entire store on error — see class docstring
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ---------- Internal helpers ----------

  /// Writes [value] to [key] only if it is within the safe size limit.
  static Future<void> _writeGuarded(String key, String value) async {
    if (value.length > _kMaxValueBytes) {
      debugPrint(
        'CurrencySecureStorage: Payload too large for key "$key" '
            '(${value.length} bytes > $_kMaxValueBytes) — rejected',
      );
      return;
    }
    await _store.write(key: key, value: value);
  }

  // ---------- Preferred FIAT ----------

  /// Save preferred fiat currency code (e.g. 'usd', 'eur', 'php').
  ///
  /// Silently skips empty strings after trimming.
  static Future<void> saveFiat(String fiat) async {
    final cleaned = fiat.trim().toLowerCase();
    if (cleaned.isEmpty) {
      debugPrint(
        'CurrencySecureStorage: saveFiat() received empty string — skipped',
      );
      return;
    }
    try {
      await _writeGuarded(_kFiatKey, cleaned);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving fiat: $e');
    }
  }

  /// Read saved preferred fiat currency. Returns `null` if not set or on error.
  static Future<String?> readFiat() async {
    try {
      final v = await _store.read(key: _kFiatKey);
      if (v == null || v.trim().isEmpty) return null;
      return v.trim();
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading fiat: $e');
      return null;
    }
  }

  /// Clear saved fiat preference.
  static Future<void> clearFiat() async {
    try {
      await _store.delete(key: _kFiatKey);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing fiat: $e');
    }
  }

  // ---------- Last-good rates cache ----------

  /// Save last successfully fetched exchange rates.
  ///
  /// A `ts` (Unix seconds) field is injected automatically if not provided.
  ///
  /// Expected shape:
  /// ```dart
  /// {
  ///   "fiat": "usd",
  ///   "usdcRate": 1.00,
  ///   "xlmRate": 0.12,
  ///   "ts": 1690000000   // optional — auto-injected if absent
  /// }
  /// ```
  static Future<void> saveLastGoodRates(Map<String, dynamic> data) async {
    try {
      final payload = <String, dynamic>{
        ...data,
        // Guarantee a timestamp so cache age is always computable.
        'ts': data['ts'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      final jsonStr = jsonEncode(payload);
      await _writeGuarded(_kRatesKey, jsonStr);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving rates: $e');
    }
  }

  /// Read last successfully fetched exchange rates.
  /// Returns `null` if not cached, unreadable, or corrupted.
  static Future<Map<String, dynamic>?> readLastGoodRates() async {
    try {
      final v = await _store.read(key: _kRatesKey);
      if (v == null || v.isEmpty) return null;

      final decoded = jsonDecode(v);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('CurrencySecureStorage: Rates cache has unexpected type — discarding');
        await clearLastGoodRates();
        return null;
      }
      return decoded;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading rates: $e');
      return null;
    }
  }

  /// Clear cached exchange rates.
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
  /// A `ts` (Unix seconds) field is injected automatically if not provided.
  ///
  /// Expected shape:
  /// ```dart
  /// {
  ///   "history": [0.10, 0.11, 0.12, ...],  // List<num>
  ///   "ts": 1690000000                      // optional — auto-injected if absent
  /// }
  /// ```
  static Future<void> saveLastGoodHistory(Map<String, dynamic> data) async {
    try {
      final payload = <String, dynamic>{
        ...data,
        'ts': data['ts'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      final jsonStr = jsonEncode(payload);
      await _writeGuarded(_kHistoryKey, jsonStr);
      debugPrint(
        'CurrencySecureStorage: Saved history cache with '
            '${(payload['history'] as List?)?.length ?? 0} data points',
      );
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving history: $e');
    }
  }

  /// Read last successfully fetched price history.
  ///
  /// Validates that `history` is a `List<num>`. Returns `null` and
  /// auto-clears if the stored data is corrupted.
  static Future<Map<String, dynamic>?> readLastGoodHistory() async {
    try {
      final v = await _store.read(key: _kHistoryKey);
      if (v == null || v.isEmpty) return null;

      final decoded = jsonDecode(v);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('CurrencySecureStorage: History cache has unexpected type — discarding');
        await clearHistory();
        return null;
      }

      // Validate history element types to prevent bad values reaching UI.
      final rawHistory = decoded['history'];
      if (rawHistory != null) {
        if (rawHistory is! List || rawHistory.any((e) => e is! num)) {
          debugPrint('CurrencySecureStorage: Corrupt history list — discarding');
          await clearHistory();
          return null;
        }
      }

      final historyLength = (decoded['history'] as List?)?.length ?? 0;
      debugPrint('CurrencySecureStorage: Loaded history cache with $historyLength data points');
      return decoded;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading history: $e');
      return null;
    }
  }

  /// Clear cached price history.
  static Future<void> clearHistory() async {
    try {
      await _store.delete(key: _kHistoryKey);
      debugPrint('CurrencySecureStorage: Cleared history cache');
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing history: $e');
    }
  }

  // ---------- Utility methods ----------

  /// Clear all cached currency data (fiat, rates, and history).
  ///
  /// Uses `eagerError: false` so a failure in one operation does not
  /// prevent the others from completing.
  static Future<void> clearAll() async {
    await Future.wait(
      [
        clearFiat(),
        clearLastGoodRates(),
        clearHistory(),
      ],
      eagerError: false,
    );
    debugPrint('CurrencySecureStorage: Cleared all currency data');
  }

  /// Returns `true` if a rate cache entry exists.
  static Future<bool> hasRateCache() async {
    final rates = await readLastGoodRates();
    return rates != null;
  }

  /// Returns `true` if a non-empty history cache exists.
  static Future<bool> hasHistoryCache() async {
    final history = await readLastGoodHistory();
    return history != null && (history['history'] as List?)?.isNotEmpty == true;
  }

  /// Returns the age of the rate cache in minutes, or `null` if unavailable.
  static Future<int?> getRateCacheAgeMinutes() async {
    final rates = await readLastGoodRates();
    if (rates == null) return null;
    return _ageInMinutes(rates['ts']);
  }

  /// Returns the age of the history cache in hours, or `null` if unavailable.
  static Future<int?> getHistoryCacheAgeHours() async {
    final history = await readLastGoodHistory();
    if (history == null) return null;
    return _ageInHours(history['ts']);
  }

  /// Returns a summary of the current cache state.
  ///
  /// Reads each cache only once to minimise I/O.
  static Future<Map<String, dynamic>> getCacheStatus() async {
    // Read once, derive all fields — avoids redundant I/O from calling
    // hasRateCache() and getRateCacheAgeMinutes() separately.
    final rates = await readLastGoodRates();
    final history = await readLastGoodHistory();

    return {
      'hasRateCache': rates != null,
      'hasHistoryCache':
      history != null && (history['history'] as List?)?.isNotEmpty == true,
      'rateCacheAgeMinutes': rates != null ? _ageInMinutes(rates['ts']) : null,
      'historyCacheAgeHours':
      history != null ? _ageInHours(history['ts']) : null,
    };
  }

  // ---------- Private helpers ----------

  /// Converts a Unix-seconds timestamp to cache age in minutes.
  /// Returns `null` if [ts] is null or not an [int].
  static int? _ageInMinutes(dynamic ts) {
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
    return DateTime.now().toUtc().difference(cachedAt).inMinutes;
  }

  /// Converts a Unix-seconds timestamp to cache age in hours.
  /// Returns `null` if [ts] is null or not an [int].
  static int? _ageInHours(dynamic ts) {
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true);
    return DateTime.now().toUtc().difference(cachedAt).inHours;
  }
}