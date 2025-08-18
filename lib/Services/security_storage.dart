import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Save a value
  static Future<void> save(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // Read a value
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  // Delete a value
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // Check if key exists
  static Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }
}
