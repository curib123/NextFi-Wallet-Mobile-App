import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SeedStorage {
  static const _storage = FlutterSecureStorage();
  static const _seedKey = '';

  /// Save seed phrase securely
  static Future<void> saveSeed(String mnemonic) async {
    await _storage.write(key: _seedKey, value: mnemonic);
  }

  /// Retrieve seed phrase
  static Future<String?> getSeed() async {
    return await _storage.read(key: _seedKey);
  }

  /// Delete seed phrase
  static Future<void> clearSeed() async {
    await _storage.delete(key: _seedKey);
  }
}
