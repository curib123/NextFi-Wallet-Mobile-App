import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:pointycastle/ecc/api.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

/// Simple wallet core focused on ETH (EVM).
class WalletService {
  /// Generate 12-word mnemonic
  static String generateMnemonic({int strength = 128}) {
    return bip39.generateMnemonic(strength: strength);
  }

  /// Validate mnemonic
  static bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  /// Derive Ethereum private key from mnemonic using BIP44 path m/44'/60'/0'/0/0
  static EthPrivateKey deriveEthKeyFromMnemonic(String mnemonic, {String path = "m/44'/60'/0'/0/0"}) {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(path);

    final priv = child.privateKey;
    if (priv == null) {
      throw StateError('Failed to derive private key');
    }
    return EthPrivateKey(Uint8List.fromList(priv));
  }

  /// Get Ethereum address from mnemonic
  static Future<EthereumAddress> addressFromMnemonic(String mnemonic) async {
    final key = deriveEthKeyFromMnemonic(mnemonic);
    return await key.address;
  }

  /// Get Ethereum public key from mnemonic
  static ECPoint publicKeyFromMnemonic(String mnemonic, {String path = "m/44'/60'/0'/0/0"}) {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(path);

    final priv = child.privateKey;
    if (priv == null) {
      throw StateError('Failed to derive private key');
    }

    // Use web3dart to get public key from private key
    final ethKey = EthPrivateKey(Uint8List.fromList(priv));
    final pubKey = ethKey.publicKey;
    return pubKey;
  }

  /// Get receiving address as hex string (for display)
  static Future<String> receivingAddress(String mnemonic) async {
    final address = await addressFromMnemonic(mnemonic);
    return address.hexEip55; // checksummed Ethereum address
  }

  /// (Optional) Send ETH — you must provide a working RPC URL and chain info
  /// Example only; add gas configuration and error handling in prod.
  static Future<String> sendEth({
    required String rpcUrl,
    required String mnemonic,
    required EthereumAddress to,
    required EtherAmount amount,
    int? chainId,
  }) async {
    final client = Web3Client(rpcUrl, http.Client());
    try {
      final creds = deriveEthKeyFromMnemonic(mnemonic);
      final txHash = await client.sendTransaction(
        creds,
        Transaction(
          to: to,
          value: amount,
        ),
        chainId: chainId,
      );
      return txHash;
    } finally {
      client.dispose();
    }
  }
}
