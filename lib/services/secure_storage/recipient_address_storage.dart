// lib/features/wallet_home/data/recipient_address_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';

/// Secure storage boundary for recipient addresses.
/// Keeps platform options + key details out of the VM.
class RecipientAddressStorage {
  static const String _storageKey = 'recipient_addresses_v1';

  // Strong platform options (consistent with your app)
  static const AndroidOptions _android = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const IOSOptions _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  const RecipientAddressStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Read all saved recipient addresses. Returns [] if nothing stored.
  Future<List<RecipientAddressModel>> readAll() async {
    final raw = await _storage.read(
      key: _storageKey,
      aOptions: _android,
      iOptions: _ios,
    );
    return RecipientAddressModel.decodeList(raw);
  }

  /// Overwrite all recipient addresses atomically.
  Future<void> writeAll(List<RecipientAddressModel> items) async {
    final payload = RecipientAddressModel.encodeList(items);
    await _storage.write(
      key: _storageKey,
      value: payload,
      aOptions: _android,
      iOptions: _ios,
    );
  }

  /// Delete the key entirely.
  Future<void> deleteAll() async {
    await _storage.delete(
      key: _storageKey,
      aOptions: _android,
      iOptions: _ios,
    );
  }
}
