import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CurrencySecureStorage {
  static const _kFiatKey = 'nextfi.currency.preferred_fiat.v1';
  static const _kRatesKey = 'nextfi.currency.last_good_rates.v1';
  static const _kHistoryKey = 'nextfi.currency.last_good_history.v1';

  static const int _kMaxValueBytes = 512 * 1024;

  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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

  static Future<void> clearFiat() async {
    try {
      await _store.delete(key: _kFiatKey);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing fiat: $e');
    }
  }

  static Future<void> saveLastGoodRates(Map<String, dynamic> data) async {
    try {
      final payload = <String, dynamic>{
        ...data,
        'ts': data['ts'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      final jsonStr = jsonEncode(payload);
      await _writeGuarded(_kRatesKey, jsonStr);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error saving rates: $e');
    }
  }

  static Future<Map<String, dynamic>?> readLastGoodRates() async {
    try {
      final v = await _store.read(key: _kRatesKey);
      if (v == null || v.isEmpty) return null;

      final decoded = jsonDecode(v);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'CurrencySecureStorage: Rates cache has unexpected type — discarding',
        );
        await clearLastGoodRates();
        return null;
      }
      return decoded;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading rates: $e');
      return null;
    }
  }

  static Future<void> clearLastGoodRates() async {
    try {
      await _store.delete(key: _kRatesKey);
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing rates: $e');
    }
  }

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

  static Future<Map<String, dynamic>?> readLastGoodHistory() async {
    try {
      final v = await _store.read(key: _kHistoryKey);
      if (v == null || v.isEmpty) return null;

      final decoded = jsonDecode(v);
      if (decoded is! Map<String, dynamic>) {
        debugPrint(
          'CurrencySecureStorage: History cache has unexpected type — discarding',
        );
        await clearHistory();
        return null;
      }

      final rawHistory = decoded['history'];
      if (rawHistory != null) {
        if (rawHistory is! List || rawHistory.any((e) => e is! num)) {
          debugPrint(
            'CurrencySecureStorage: Corrupt history list — discarding',
          );
          await clearHistory();
          return null;
        }
      }

      final historyLength = (decoded['history'] as List?)?.length ?? 0;
      debugPrint(
        'CurrencySecureStorage: Loaded history cache with $historyLength data points',
      );
      return decoded;
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error reading history: $e');
      return null;
    }
  }

  static Future<void> clearHistory() async {
    try {
      await _store.delete(key: _kHistoryKey);
      debugPrint('CurrencySecureStorage: Cleared history cache');
    } catch (e) {
      debugPrint('CurrencySecureStorage: Error clearing history: $e');
    }
  }

  static Future<void> clearAll() async {
    await Future.wait([
      clearFiat(),
      clearLastGoodRates(),
      clearHistory(),
    ], eagerError: false);
    debugPrint('CurrencySecureStorage: Cleared all currency data');
  }

  static Future<bool> hasRateCache() async {
    final rates = await readLastGoodRates();
    return rates != null;
  }

  static Future<bool> hasHistoryCache() async {
    final history = await readLastGoodHistory();
    return history != null && (history['history'] as List?)?.isNotEmpty == true;
  }

  static Future<int?> getRateCacheAgeMinutes() async {
    final rates = await readLastGoodRates();
    if (rates == null) return null;
    return _ageInMinutes(rates['ts']);
  }

  static Future<int?> getHistoryCacheAgeHours() async {
    final history = await readLastGoodHistory();
    if (history == null) return null;
    return _ageInHours(history['ts']);
  }

  static Future<Map<String, dynamic>> getCacheStatus() async {
    final rates = await readLastGoodRates();
    final history = await readLastGoodHistory();

    return {
      'hasRateCache': rates != null,
      'hasHistoryCache':
          history != null && (history['history'] as List?)?.isNotEmpty == true,
      'rateCacheAgeMinutes': rates != null ? _ageInMinutes(rates['ts']) : null,
      'historyCacheAgeHours': history != null
          ? _ageInHours(history['ts'])
          : null,
    };
  }

  static int? _ageInMinutes(dynamic ts) {
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      ts * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().difference(cachedAt).inMinutes;
  }

  static int? _ageInHours(dynamic ts) {
    if (ts is! int) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      ts * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().difference(cachedAt).inHours;
  }
}
