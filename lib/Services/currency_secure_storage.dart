import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure, cached storage for currency prefs and "last good" rates.
class CurrencySecureStorage {
  // ── Keys (versioned) ────────────────────────────────────────────────────────
  static const _kFiat  = 'currency_pref_fiat_v1';
  static const _kRates = 'currency_last_good_rates_v1';

  // ── Platform options (more robust on Android & iOS) ────────────────────────
  static const AndroidOptions _aOpts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true, // auto-clear if keystore corruption occurs
    sharedPreferencesName: 'next_fi_secure_prefs',
    preferencesKeyPrefix: 'cf_', // small prefix namespace
  );

  static const IOSOptions _iOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock, // readable after first unlock
    synchronizable: false,
  );

  // One instance with default options.
  static final FlutterSecureStorage _s =
  const FlutterSecureStorage(aOptions: _aOpts, iOptions: _iOpts);

  // ── In-memory caches to reduce IO ──────────────────────────────────────────
  static String? _fiatCache;
  static Map<String, dynamic>? _ratesCache;

  // Basic fiat code validator: 3–5 letters (e.g., usd, php, eur)
  static final RegExp _fiatRe = RegExp(r'^[a-z]{3,5}$');

  // ── Fiat helpers ───────────────────────────────────────────────────────────
  /// Save fiat (normalized to lowercase). Throws [ArgumentError] if invalid.
  static Future<void> saveFiat(String fiat) async {
    final v = fiat.trim().toLowerCase();
    if (!_fiatRe.hasMatch(v)) {
      throw ArgumentError('Fiat must be a 3–5 letter code (e.g., usd, php).');
    }
    await _safeWrite(_kFiat, v);
    _fiatCache = v;
  }

  /// Read saved fiat (cached). Returns null if not set.
  static Future<String?> readFiat() async {
    if (_fiatCache != null) return _fiatCache;
    _fiatCache = await _safeRead(_kFiat);
    return _fiatCache;
  }

  /// Read saved fiat or a default (e.g., 'usd' or 'php') if not set/invalid.
  static Future<String> readFiatOrDefault([String defaultFiat = 'usd']) async {
    final v = await readFiat();
    if (v != null && _fiatRe.hasMatch(v)) return v;
    return defaultFiat;
  }

  static Future<void> clearFiat() async {
    await _safeDelete(_kFiat);
    _fiatCache = null;
  }

  // ── Last-good rates helpers ────────────────────────────────────────────────
  /// Persists a JSON-serializable map and adds a `_ts` (epoch ms) field.
  /// If you already include `_ts`, it won't be overwritten.
  static Future<void> saveLastGoodRates(Map<String, dynamic> m) async {
    final withTs = Map<String, dynamic>.from(m);
    withTs.putIfAbsent('_ts', () => DateTime.now().millisecondsSinceEpoch);
    final payload = jsonEncode(withTs);
    await _safeWrite(_kRates, payload);
    _ratesCache = withTs;
  }

  /// Reads the last-good rates map. If [maxAge] is provided and the saved
  /// snapshot is older than that, returns null.
  static Future<Map<String, dynamic>?> readLastGoodRates({Duration? maxAge}) async {
    if (_ratesCache == null) {
      final v = await _safeRead(_kRates);
      if (v == null || v.isEmpty) return null;
      try {
        final decoded = jsonDecode(v);
        _ratesCache = (decoded is Map<String, dynamic>) ? decoded : null;
      } catch (_) {
        _ratesCache = null;
      }
    }
    if (_ratesCache == null) return null;

    if (maxAge != null) {
      final ts = _ratesCache!['_ts'];
      if (ts is int) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ts));
        if (age > maxAge) return null;
      }
    }
    return _ratesCache;
  }

  static Future<void> clearLastGoodRates() async {
    await _safeDelete(_kRates);
    _ratesCache = null;
  }

  // ── Low-level safe wrappers (handle platform/keychain errors) ──────────────
  static Future<void> _safeWrite(String key, String value) async {
    try {
      await _s.write(key: key, value: value);
    } on PlatformException {
      // If keychain/keystore hiccups, try a reset-on-error path.
      await _s.delete(key: key);
      await _s.write(key: key, value: value);
    }
  }

  static Future<String?> _safeRead(String key) async {
    try {
      return await _s.read(key: key);
    } on PlatformException {
      // Corruption or access issue: treat as missing.
      return null;
    }
  }

  static Future<void> _safeDelete(String key) async {
    try {
      await _s.delete(key: key);
    } on PlatformException {
      // Best-effort: ignore.
    }
  }

  // ── Utility: clear everything this helper owns ─────────────────────────────
  static Future<void> clearAll() async {
    await Future.wait([clearFiat(), clearLastGoodRates()]);
  }
}
