// stellar_wallet_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';

/// Service for mnemonic generation, validation, and key management
class StellarWalletManager extends StellarBaseService {
  final FlutterSecureStorage _secureStorage;

  StellarWalletManager({
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    FlutterSecureStorage? secureStorage,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(
        sdk: sdk,
        sdkQuickNode: sdkQuickNode,
        quickNodeUrlMainnet: quickNodeUrlMainnet,
        quickNodeUrlTestnet: quickNodeUrlTestnet,
        quickNodeDefaultHeaders: quickNodeDefaultHeaders,
      );

  // ──────────────────────────────────────────────────────────────────────────
  // Mnemonic Generation
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> generateMnemonic12() async {
    try {
      return await Wallet.generate12WordsMnemonic();
    } catch (e) {
      fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  Future<String> generateMnemonic24() async {
    try {
      return await Wallet.generate24WordsMnemonic();
    } catch (e) {
      fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  Future<String> generateMnemonic({int wordCount = 12}) async {
    try {
      switch (wordCount) {
        case 12:
          return await Wallet.generate12WordsMnemonic();
        case 18:
          return await Wallet.generate18WordsMnemonic();
        case 24:
          return await Wallet.generate24WordsMnemonic();
        default:
          return await Wallet.generate12WordsMnemonic();
      }
    } catch (e) {
      fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  Future<bool> validateMnemonic(String mnemonic) async {
    try {
      return await Wallet.validate(mnemonic);
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Wallet Creation
  // ──────────────────────────────────────────────────────────────────────────

  Future<Wallet> createWallet(String mnemonic, {String passphrase = ''}) async {
    try {
      return await Wallet.from(mnemonic, passphrase: passphrase);
    } catch (e) {
      fail(
        'Invalid recovery phrase',
        technicalError: e,
        advice:
        'Please check your recovery phrase and try again. Make sure all words are spelled correctly',
      );
    }
  }

  Future<KeyPair> getKeyPairFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
      return await wallet.getKeyPair(index: index);
    } catch (e) {
      fail(
        'Unable to derive account from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );
    }
  }

  Future<String> getAccountIdFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
      return await wallet.getAccountId(index: index);
    } catch (e) {
      fail(
        'Unable to derive account from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );
    }
  }

  Future<List<KeyPair>> deriveAccounts(
      String mnemonic, {
        required int count,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(
        mnemonic,
        passphrase: passphrase,
      );

      final accounts = <KeyPair>[];

      for (int i = 0; i < count; i++) {
        accounts.add(await wallet.getKeyPair(index: i));
      }

      return accounts; // ✅ RETURN ADDED
    } catch (e) {
      fail(
        'Unable to derive accounts from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );

      rethrow; // ✅ ensures function never returns null
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Secure Storage
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> storeMnemonic(String mnemonic,
      {String key = 'stellar_mnemonic'}) async {
    try {
      await _secureStorage.write(key: key, value: mnemonic);
    } catch (e) {
      fail(
        'Unable to save recovery phrase securely',
        technicalError: e,
        advice: 'Please check your device storage permissions and try again',
      );
    }
  }

  Future<String?> retrieveMnemonic({String key = 'stellar_mnemonic'}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      fail(
        'Unable to retrieve recovery phrase',
        technicalError: e,
        advice: 'Please check your device security settings',
      );
    }
  }

  Future<void> deleteMnemonic({String key = 'stellar_mnemonic'}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      fail(
        'Unable to delete recovery phrase',
        technicalError: e,
        advice: 'Please try again or restart the app',
      );
    }
  }

  Future<void> storeSecretSeed(
      String secretSeed, {
        String key = 'stellar_secret',
      }) async {
    try {
      await _secureStorage.write(key: key, value: secretSeed);
    } catch (e) {
      fail(
        'Unable to save secret key securely',
        technicalError: e,
        advice: 'Please check your device storage permissions and try again',
      );
    }
  }

  Future<String?> retrieveSecretSeed({String key = 'stellar_secret'}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      fail(
        'Unable to retrieve secret key',
        technicalError: e,
        advice: 'Please check your device security settings',
      );
    }
  }

  Future<KeyPair?> getKeyPairFromStorage(
      {String key = 'stellar_secret'}) async {
    try {
      final secret = await _secureStorage.read(key: key);
      if (secret == null) return null;
      return KeyPair.fromSecretSeed(secret);
    } catch (e) {
      fail(
        'Unable to load account key',
        technicalError: e,
        advice: 'Your account key may be invalid. Please check your settings',
      );
    }
  }
}