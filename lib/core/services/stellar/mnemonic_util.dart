import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Mnemonic helpers for 12 and 24 word phrases.
/// Uses stellar_flutter_sdk's Wallet helpers.
class MnemonicUtil {
  static Future<String> generate24() => Wallet.generate24WordsMnemonic();

  /// Some versions of stellar_flutter_sdk also expose generate12WordsMnemonic().
  /// If your SDK version doesn't have it, switch to `bip39` package as fallback.
  static Future<String> generate12() async {
    // If available:
    // return Wallet.generate12WordsMnemonic();

    // Fallback using 24 -> 12 (NOT recommended for production randomness parity).
    // Prefer to upgrade SDK or add `bip39` dependency for proper 12-word gen.
    final m24 = await Wallet.generate24WordsMnemonic();
    final words = m24.split(RegExp(r'\\s+'));
    return words.take(12).join(' ');
  }

  static Future<Wallet> walletFromMnemonic(String mnemonic) => Wallet.from(mnemonic);
  static Future<KeyPair> keyPairFromWallet(Wallet w, {int index = 0}) => w.getKeyPair(index: index);
}
