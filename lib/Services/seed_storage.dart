import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SeedStorage {
  static const _seedKey = 'nextfi.seed.mnemonic.v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // More secure on Android
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock, // Secure on iOS
    ),
  );

  /// Save seed phrase securely and verify it.
  static Future<bool> saveSeed(String mnemonic) async {
    final value = mnemonic.trim();
    if (value.isEmpty) return false;

    await _storage.write(key: _seedKey, value: value);

    // Verify by reading it back
    final back = await _storage.read(key: _seedKey);
    return back == value;
  }

  /// Retrieve seed phrase (or null if not set).
  static Future<String?> getSeed() async {
    return await _storage.read(key: _seedKey);
  }

  /// Delete seed phrase.
  static Future<void> clearSeed() async {
    await _storage.delete(key: _seedKey);
  }
}
