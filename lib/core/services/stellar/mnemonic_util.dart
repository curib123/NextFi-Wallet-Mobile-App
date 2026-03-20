import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class MnemonicUtil {
  static Future<String> generate24() => Wallet.generate24WordsMnemonic();

  static Future<String> generate12() async {
    final m24 = await Wallet.generate24WordsMnemonic();
    final words = m24.split(RegExp(r'\\s+'));
    return words.take(12).join(' ');
  }

  static Future<Wallet> walletFromMnemonic(String mnemonic) =>
      Wallet.from(mnemonic);
  static Future<KeyPair> keyPairFromWallet(Wallet w, {int index = 0}) =>
      w.getKeyPair(index: index);
}
