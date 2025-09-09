import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Immutable, tamper-resistant profit-address vault.
/// - Source of truth is the compiled constant below.
/// - Secure storage is only a cache; any mismatch is overwritten each read.
/// - No public write/clear; class is `final` so it can't be subclassed.
final class ProfitAddressVaultSecureStorage {
  static const String _kKey = 'profit_address_v1';

  /// TODO: put your fee address here (must be a valid G... account).
  static const String defaultProfitAddress = 'G...YOUR_CONSTANT_FEE_ADDRESS...';

  final FlutterSecureStorage _storage;

  const ProfitAddressVaultSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          resetOnError: true,
        ),
        iOptions: IOSOptions(
          // Readable after first device unlock; persisted across reboots.
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  /// Returns the profit address.
  /// Also enforces (writes) the constant into secure storage every time.
  Future<String> readOrInit() async {
    _validate(defaultProfitAddress);

    try {
      final stored = await _storage.read(key: _kKey);
      if (stored != defaultProfitAddress) {
        // Initialize or self-heal any tampering/old backup.
        await _storage.write(key: _kKey, value: defaultProfitAddress);
      }
    } catch (_) {
      // If storage is unavailable, still return the constant.
    }

    return defaultProfitAddress;
  }

  // ---- No setters, no deleters. ----

  void _validate(String g) {
    // Throws if not a valid Stellar account id (StrKey ed25519)
    KeyPair.fromAccountId(g);
  }
}