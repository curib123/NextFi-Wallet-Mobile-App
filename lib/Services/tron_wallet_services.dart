import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:pointycastle/ecc/api.dart';
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart';
import 'package:web3dart/crypto.dart';

/// Simple Tron (TRX + USDT TRC20) wallet service with 1% profit fee
class TronWalletService {
  static const String defaultPath = "m/44'/195'/0'/0/0";
  static const String tronGridApi = 'https://api.trongrid.io';

  /// Profit address for fee
  static const String profitAddress = 'YOUR_PROFIT_ADDRESS_HERE';

  /// Generate 12-word mnemonic
  static String generateMnemonic({int strength = 128}) =>
      bip39.generateMnemonic(strength: strength);

  /// Validate mnemonic
  static bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  /// Derive Tron private key from mnemonic
  static Uint8List derivePrivateKey(String mnemonic, {String path = defaultPath}) {
    if (!validateMnemonic(mnemonic)) throw ArgumentError('Invalid mnemonic');
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(path);
    final priv = child.privateKey;
    if (priv == null) throw StateError('Failed to derive private key');
    return Uint8List.fromList(priv);
  }

  /// Derive public key from private key
  static ECPoint publicKeyFromPrivateKey(Uint8List privKey) {
    final ecDomain = ECDomainParameters('secp256k1');
    final BigInt privateInt = BigInt.parse(hex.encode(privKey), radix: 16);
    final pubKey = ecDomain.G * privateInt;
    if (pubKey == null) throw StateError('Failed to derive public key');
    return pubKey;
  }

  /// Get Tron address from public key
  static String tronAddressFromPublicKey(ECPoint pubKey) {
    final pubBytes = pubKey.getEncoded(false).sublist(1); // remove 0x04 prefix
    final hash = sha3_256(pubBytes);
    final addressBytes = Uint8List.fromList([0x41, ...hash.sublist(12)]);
    return base58Encode(addressBytes);
  }

  static String base58Encode(Uint8List bytes) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    BigInt intData = BigInt.parse(hex.encode(bytes), radix: 16);

    String result = '';
    while (intData > BigInt.zero) {
      final mod = intData % BigInt.from(58);
      result = alphabet[mod.toInt()] + result;
      intData = intData ~/ BigInt.from(58);
    }
    for (var byte in bytes) {
      if (byte == 0) result = '1' + result;
      else break;
    }
    return result;
  }

  static Uint8List sha3_256(Uint8List input) => keccak256(input);

  /// Get TRX balance (in SUN)
  static Future<int> getTrxBalance(String address) async {
    if (address.isEmpty) throw ArgumentError('Address is empty');
    final url = Uri.parse('$tronGridApi/v1/accounts/$address');
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('Failed to get TRX balance');
    final data = jsonDecode(res.body);
    return (data['data']?[0]?['balance'] ?? 0) as int;
  }

  /// Get USDT TRC20 balance
  static Future<double> getUsdtBalance(
      String address, {
        String contractAddress = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      }) async {
    if (address.isEmpty) throw ArgumentError('Address is empty');
    final url = Uri.parse('$tronGridApi/v1/accounts/$address/contracts/$contractAddress');
    final res = await http.get(url);
    if (res.statusCode != 200) throw Exception('Failed to get USDT balance');
    final data = jsonDecode(res.body);
    final balance = data['data']?[0]?['balance'] ?? 0;
    return balance / 1e6; // USDT has 6 decimals
  }

  /// Send USDT with 1% profit fee (conceptual; implement signing via Tron SDK or TronGrid)
  static Future<List<String>> sendUsdtWithFee({
    required Uint8List privateKey,
    required String toAddress,
    required double amount,
    String contractAddress = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be > 0');
    if (toAddress.isEmpty) throw ArgumentError('Recipient address is empty');

    // Calculate amounts using integer math for precision
    final receiverAmount = amount * 0.99;
    final feeAmount = amount * 0.01;

    // Conceptual: send two transactions
    final tx1Hash = await sendTrc20(privateKey, toAddress, receiverAmount, contractAddress);
    final tx2Hash = await sendTrc20(privateKey, profitAddress, feeAmount, contractAddress);

    return [tx1Hash, tx2Hash];
  }

  /// Placeholder for TRC20 transaction send
  static Future<String> sendTrc20(
      Uint8List privateKey,
      String toAddress,
      double amount,
      String contractAddress,
      ) async {
    // Implement signing and broadcasting via Tron SDK or TronGrid API
    throw UnimplementedError(
        'TRC20 transfer requires signing and broadcasting. Implement via Tron SDK or TronGrid API.');
  }

  /// Send TRX with 1% profit fee
  static Future<List<String>> sendTrxWithFee({
    required Uint8List privateKey,
    required String toAddress,
    required int amountSun, // TRX in SUN (1 TRX = 1_000_000 SUN)
  }) async {
    if (amountSun <= 0) throw ArgumentError('Amount must be > 0');
    if (toAddress.isEmpty) throw ArgumentError('Recipient address is empty');

    // Calculate amounts
    final receiverAmount = (amountSun * 0.99).toInt();
    final feeAmount = amountSun - receiverAmount;

    // Conceptual: send two transactions
    final tx1Hash = await sendTrx(privateKey, toAddress, receiverAmount);
    final tx2Hash = await sendTrx(privateKey, profitAddress, feeAmount);

    return [tx1Hash, tx2Hash];
  }

  /// Placeholder for TRX transaction send
  static Future<String> sendTrx(
      Uint8List privateKey,
      String toAddress,
      int amountSun,
      ) async {
    // Implement signing and broadcasting via Tron SDK or TronGrid API
    throw UnimplementedError(
        'TRX transfer requires signing and broadcasting. Implement via Tron SDK or TronGrid API.');
  }

}
