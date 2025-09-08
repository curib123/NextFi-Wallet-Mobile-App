// Secure storage helper for wallet-specific secrets (e.g., wallet name)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletSecureStorage {
  static const _kWalletName = 'wallet_name_v1';
  static const String defaultWalletName = 'My Wallet';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Optional platform options (tuned defaults; safe to remove if undesired)
  static const AndroidOptions _androidOptions =
  AndroidOptions(encryptedSharedPreferences: true);
  static const IOSOptions _iosOptions =
  IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  static Future<bool> saveWalletName(String name) async {
    try {
      final v = name.trim();
      if (v.isEmpty) return false;
      await _storage.write(
        key: _kWalletName,
        value: v,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> readWalletName() async {
    try {
      return await _storage.read(
        key: _kWalletName,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
    } catch (_) {
      return null;
    }
  }

  /// New: always returns a non-empty name.
  static Future<String> readWalletNameOrDefault([String fallback = defaultWalletName]) async {
    final raw = await readWalletName();
    final v = raw?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  static Future<bool> hasWalletName() async {
    try {
      final v = await readWalletName();
      return (v != null && v.trim().isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteWalletName() async {
    try {
      await _storage.delete(
        key: _kWalletName,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Optional helper: ensure there is a name saved; writes the default if absent.
  static Future<String> ensureWalletName([String fallback = defaultWalletName]) async {
    final hasName = await hasWalletName();
    if (!hasName) {
      await saveWalletName(fallback);
      return fallback;
    }
    return await readWalletNameOrDefault(fallback);
  }
}
