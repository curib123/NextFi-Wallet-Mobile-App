import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';

class RecipientAddressStorage {
  static const String _storageKey = 'recipient_addresses_v1';

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

  Future<List<RecipientAddressModel>> readAll() async {
    final raw = await _storage.read(
      key: _storageKey,
      aOptions: _android,
      iOptions: _ios,
    );
    return RecipientAddressModel.decodeList(raw);
  }

  Future<void> writeAll(List<RecipientAddressModel> items) async {
    final payload = RecipientAddressModel.encodeList(items);
    await _storage.write(
      key: _storageKey,
      value: payload,
      aOptions: _android,
      iOptions: _ios,
    );
  }

  Future<void> deleteAll() async {
    await _storage.delete(key: _storageKey, aOptions: _android, iOptions: _ios);
  }
}
