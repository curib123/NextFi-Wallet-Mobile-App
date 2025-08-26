import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:pointycastle/ecc/api.dart';
import 'package:crypto/crypto.dart' as dart_crypto; // for double-sha256 checksum
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart';
import 'package:web3dart/crypto.dart' show keccak256;

/// Simple Tron (TRX + USDT TRC20) wallet service with 1% profit fee
class TronWalletService {
  static const String defaultPath = "m/44'/195'/0'/0/0";
  static const String tronGridApi = 'https://api.trongrid.io';

  /// Profit address for fee (TRON base58 address). Replace with real one.
  static const String profitAddress = 'YOUR_PROFIT_ADDRESS_HERE';

  /// Generate 12-word mnemonic
  static String generateMnemonic({int strength = 128}) =>
      bip39.generateMnemonic(strength: strength);

  /// Validate mnemonic
  static bool validateMnemonic(String mnemonic) =>
      bip39.validateMnemonic(mnemonic);

  /// Get transaction history (TRX + USDT + other TRC20 transfers)
  /// [limit] controls how many txs to fetch (max 200 per TronGrid docs)
  static Future<List<Map<String, dynamic>>> getTransactionHistory(
      String base58Address, {
        int limit = 20,
        int start = 0,
      }) async {
    if (base58Address.isEmpty) {
      throw ArgumentError('Address is empty');
    }

    final url = Uri.parse(
      '$tronGridApi/v1/accounts/$base58Address/transactions?limit=$limit&start=$start&sort=-timestamp',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception(
          'Failed to get transaction history: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    final List txs = data['data'] ?? [];

    // Normalize output
    return txs.map<Map<String, dynamic>>((tx) {
      return {
        'txID': tx['txID'],
        'timestamp': tx['raw_data']?['timestamp'],
        'type': tx['raw_data']?['contract']?[0]?['type'],
        'contract': tx['raw_data']?['contract']?[0]?['parameter']?['value'],
        'ret': tx['ret'],
      };
    }).toList();
  }

  /// Derive Tron private key from mnemonic
  /// Returns Uint8List (32 bytes)
  static Uint8List derivePrivateKey(String mnemonic,
      {String path = defaultPath}) {
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }

    // bip39.mnemonicToSeed returns Uint8List for the Dart bip39 package.
    // If your package returns a hex string, convert it accordingly.
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(path);
    final priv = child.privateKey;
    if (priv == null) throw StateError('Failed to derive private key');
    // Ensure 32 bytes
    if (priv.length != 32) {
      // pad or slice just in case, but typically it is 32 bytes
      final res = Uint8List.fromList(List.filled(32, 0));
      final offset = 32 - priv.length;
      for (var i = 0; i < priv.length && i < 32; i++) {
        res[offset + i] = priv[i];
      }
      return res;
    }
    return Uint8List.fromList(priv);
  }


  void listenForIncomingPayments(String address) async {
    final socket = await WebSocket.connect('wss://api.trongrid.io/v1/transactions/subscribe');

    // Subscribe to account events
    socket.add(jsonEncode({
      "event": "subscribe",
      "address": address,
    }));

    socket.listen((data) {
      final msg = jsonDecode(data);
      print("🔔 Incoming tx: $msg");
      // You can filter for transfers to your address
    });
  }

  /// Derive public key (uncompressed) from private key
  /// Returns ECPoint (pointycastle)
  static ECPoint publicKeyFromPrivateKey(Uint8List privKey) {
    final ecDomain = ECDomainParameters('secp256k1');
    final BigInt privateInt = BigInt.parse(hex.encode(privKey), radix: 16);
    final pubKey = ecDomain.G * privateInt;
    if (pubKey == null) throw StateError('Failed to derive public key');
    return pubKey;
  }

  /// Get Tron base58check address from public key
  /// Tron address = 0x41 + last 20 bytes of keccak256(pubkey_no_prefix) then Base58Check
  static String tronAddressFromPublicKey(ECPoint pubKey) {
    // pubKey.getEncoded(false) -> 0x04 + X (32 bytes) + Y (32 bytes)
    final pubBytes = pubKey.getEncoded(false).sublist(1); // drop 0x04
    final hashed = keccak256(pubBytes); // returns Uint8List
    // Tron address bytes: 0x41 + last 20 bytes of keccak hash
    final addressBytes = Uint8List.fromList([0x41, ...hashed.sublist(12)]);
    return base58CheckEncode(addressBytes);
  }

  /// Base58Check encode (Tron uses Base58Check with double SHA256 checksum)
  static String base58CheckEncode(Uint8List payload) {
    // Compute checksum = first 4 bytes of sha256(sha256(payload))
    final sha256Digest = dart_crypto.sha256.convert(payload).bytes;
    final sha256Digest2 = dart_crypto.sha256.convert(sha256Digest).bytes;
    final checksum = sha256Digest2.sublist(0, 4);

    final full = Uint8List.fromList([...payload, ...checksum]);
    return base58Encode(full);
  }

  /// Base58 encode implementation
  static String base58Encode(Uint8List bytes) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    // Convert bytes -> BigInt
    final hexStr = hex.encode(bytes);
    BigInt intData = BigInt.parse(hexStr, radix: 16);

    // Encode
    String result = '';
    final big58 = BigInt.from(58);
    while (intData > BigInt.zero) {
      final mod = intData % big58;
      result = alphabet[mod.toInt()] + result;
      intData = intData ~/ big58;
    }

    // Add '1' for each leading 0 byte
    for (var i = 0; i < bytes.length && bytes[i] == 0; i++) {
      result = '1' + result;
    }

    return result;
  }

  /// Get TRX balance (in SUN)
  static Future<int> getTrxBalance(String base58Address) async {
    if (base58Address.isEmpty) throw ArgumentError('Address is empty');
    final url = Uri.parse('$tronGridApi/v1/accounts/$base58Address');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Failed to get TRX balance: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data['data']?[0]?['balance'] ?? 0) as int;
  }

  /// Get USDT TRC20 balance (reads token balance via accounts/contracts endpoint)
  static Future<double> getUsdtBalance(
      String base58Address, {
        String contractAddress = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      }) async {
    if (base58Address.isEmpty) throw ArgumentError('Address is empty');
    final url = Uri.parse('$tronGridApi/v1/accounts/$base58Address/contracts/$contractAddress');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Failed to get USDT balance: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body);
    final balance = data['data']?[0]?['balance'] ?? 0;
    return (balance as num) / 1e6; // USDT has 6 decimals on TRC20
  }

  /// Send USDT with 1% profit fee (conceptual; implement signing via Tron SDK)
  /// Returns list of tx hashes (receiver tx, fee tx)
  static Future<List<String>> sendUsdtWithFee({
    required Uint8List privateKey,
    required String toAddress,
    required double amount,
    String contractAddress = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be > 0');
    if (toAddress.isEmpty) throw ArgumentError('Recipient address is empty');

    // Use integer arithmetic for token amounts
    final amountInt = (amount * 1e6).round(); // USDT 6 decimals
    final feeInt = (amountInt * 1) ~/ 100; // 1%
    final receiverInt = amountInt - feeInt;

    // Conceptual: create, sign and broadcast two TRC20 transfers:
    //  - to toAddress for receiverInt (token base units)
    //  - to profitAddress for feeInt
    //
    // Implement with Tron SDK or manual transaction building + signing.
    final tx1Hash = await sendTrc20(privateKey, toAddress, receiverInt, contractAddress);
    final tx2Hash = await sendTrc20(privateKey, profitAddress, feeInt, contractAddress);
    return [tx1Hash, tx2Hash];
  }

  /// Placeholder for TRC20 transaction send
  /// amount is token integer units (not decimals)
  static Future<String> sendTrc20(
      Uint8List privateKey,
      String toAddress,
      int amountInteger,
      String contractAddress,
      ) async {
    // Implement signing and broadcasting via Tron SDK or TronGrid API.
    // Typical flow:
    //  1. Build TRC20 transfer trigger transaction (contract trigger) via /wallet/triggersmartcontract
    //  2. Sign the returned transaction hex with private key (ECDSA secp256k1)
    //  3. Broadcast via /wallet/broadcasttransaction
    //
    // You can use a Tron Dart SDK or port the logic from TronWeb.
    throw UnimplementedError(
        'TRC20 transfer requires signing and broadcasting. Implement via Tron SDK or TronGrid API.');
  }

  /// Send TRX with 1% profit fee (amountSun = SUN)
  static Future<List<String>> sendTrxWithFee({
    required Uint8List privateKey,
    required String toAddress,
    required int amountSun, // TRX in SUN (1 TRX = 1_000_000 SUN)
  }) async {
    if (amountSun <= 0) throw ArgumentError('Amount must be > 0');
    if (toAddress.isEmpty) throw ArgumentError('Recipient address is empty');

    final feeAmount = (amountSun * 1) ~/ 100; // 1%
    final receiverAmount = amountSun - feeAmount;

    final tx1Hash = await sendTrx(privateKey, toAddress, receiverAmount);
    final tx2Hash = await sendTrx(privateKey, profitAddress, feeAmount);
    return [tx1Hash, tx2Hash];
  }

  /// Placeholder for TRX send
  static Future<String> sendTrx(
      Uint8List privateKey,
      String toAddress,
      int amountSun,
      ) async {
    // Implement: create transfer transaction (wallet/createtransaction), sign, and broadcast.
    throw UnimplementedError('TRX transfer requires signing and broadcasting. Implement via Tron SDK or TronGrid API.');
  }
}
