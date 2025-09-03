import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:convert/convert.dart' as conv;
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:http/http.dart' as http;
import 'package:pointycastle/ecc/api.dart';
// Use web3dart's crypto for keccak256 and ECDSA signing (r,s,v)
import 'package:web3dart/crypto.dart' as web3; // keccak256, sign, MsgSignature

/* ========================= Errors & Config ========================= */

class TronError implements Exception {
  final String message;
  final int? status;
  final Object? inner;
  TronError(this.message, {this.status, this.inner});
  @override
  String toString() => 'TronError(status=$status, message=$message, inner=$inner)';
}

class TronClientConfig {
  /// Fullnode or TronGrid base URL, e.g.:
  ///   mainnet: https://api.trongrid.io
  ///   shasta : https://api.shasta.trongrid.io
  final String baseUrl;

  /// Optional TronGrid API key header: TRON-PRO-API-KEY
  final String? tronProApiKey;

  /// HTTP timeout per request
  final Duration timeout;

  /// Retries for transient HTTP errors
  final int maxRetries;

  const TronClientConfig({
    this.baseUrl = 'https://api.trongrid.io',
    this.tronProApiKey = 'fe46f008-ba3b-4117-ae10-3043aaf04bc2',
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  });
}

/* ========================= Service ========================= */

class TronWalletService {
  static const String defaultPath = "m/44'/195'/0'/0/0";

// Add/replace these constants near the top
  static const String USDT_TRC20_MAINNET = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
  static const String USDT_TRC20_SHASTA  = 'TG3XXyExBkPp9nzdajDZsozEu4BkaSJozs';


  final TronClientConfig _cfg;
  final http.Client _http;
  final void Function(String msg)? _log;

  TronWalletService(
      TronClientConfig cfg, {
        http.Client? httpClient,
        void Function(String msg)? logger,
      })  : _cfg = cfg,
        _http = httpClient ?? http.Client(),
        _log = logger;

  void dispose() => _http.close();

  /* ---------------- Mnemonic / Keys ---------------- */

  static String generateMnemonic({int strength = 128}) =>
      bip39.generateMnemonic(strength: strength);

  static bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic);

  /// Derive 32-byte private key (BIP44: m/44'/195'/0'/0/0 by default)
  static Uint8List derivePrivateKey(String mnemonic, {String path = defaultPath}) {
    if (!validateMnemonic(mnemonic)) throw TronError('Invalid mnemonic');
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath(path);
    final priv = child.privateKey;
    if (priv == null || priv.isEmpty) throw TronError('Failed to derive private key');
    if (priv.length == 32) return Uint8List.fromList(priv);
    final out = Uint8List(32);
    final off = 32 - priv.length;
    for (var i = 0; i < priv.length && i < 32; i++) {
      out[off + i] = priv[i];
    }
    return out;
  }

  /// secp256k1 public key (uncompressed ECPoint)
  static ECPoint publicKeyFromPrivateKey(Uint8List privKey) {
    final ec = ECDomainParameters('secp256k1');
    final d = BigInt.parse(conv.hex.encode(privKey), radix: 16);
    final P = ec.G * d;
    if (P == null) throw TronError('Failed to derive public key');
    return P;
  }

  /// Tron Base58Check address from EC public key.
  /// Tron address = 0x41 + last 20 bytes of keccak256(uncompressed_pubkey_without_prefix)
  static String tronAddressFromPublicKey(ECPoint pubKey) {
    final pubBytes = pubKey.getEncoded(false).sublist(1); // drop 0x04
    final hashed = web3.keccak256(pubBytes);
    final addressBytes = Uint8List.fromList([0x41, ...hashed.sublist(12)]);
    return _base58CheckEncode(addressBytes);
  }

  static String tronAddressFromMnemonic(String mnemonic, {String path = defaultPath}) {
    final priv = derivePrivateKey(mnemonic, path: path);
    final pub = publicKeyFromPrivateKey(priv);
    return tronAddressFromPublicKey(pub);
  }

  static String tronAddressFromPrivateKey(Uint8List priv) {
    final pub = publicKeyFromPrivateKey(priv);
    return tronAddressFromPublicKey(pub);
  }

  /* ---------------- On-chain Reads ---------------- */

  Future<int> getTrxBalance(String base58Address) async {
    _ensureAddress(base58Address);
    final uri = Uri.parse('${_cfg.baseUrl}/v1/accounts/$base58Address');
    final resp = await _get(uri);
    final data = _safeJson(resp);
    final bal = (data['data'] is List && data['data'].isNotEmpty)
        ? (data['data'][0]['balance'] ?? 0)
        : 0;
    return (bal as num).toInt();
  }

  /// Read TRC20 `decimals()` via triggerconstantcontract (works on mainnet & testnets).
  Future<int> getTrc20Decimals(String contractAddress) async {
    _ensureAddress(contractAddress);
    final uri = Uri.parse('${_cfg.baseUrl}/wallet/triggerconstantcontract');
    final res = await _http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'contract_address': contractAddress,
        'function_selector': 'decimals()',
        // any valid Tron address is fine as owner for constant calls:
        'owner_address': 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb', // foundation addr
        'visible': true,
      }),
    ).timeout(_cfg.timeout);
    final j = _safeJson(res);
    final hex = (j['constant_result'] is List && j['constant_result'].isNotEmpty)
        ? (j['constant_result'][0] as String)
        : '0';
    try {
      return int.parse(hex, radix: 16);
    } catch (_) {
      return 6; // sensible default for USDT
    }
  }

  /// Scan the "holders" list for a single address’s raw balance (BigInt).
  /// Uses GET /v1/contracts/{contract}/tokens with fingerprint pagination.
  /// NOTE: This endpoint is optimized for listing holders (top balances first).
  /// For per-address lookups, it's less efficient than `balanceOf` or
  /// `/v1/accounts/{addr}/tokens`. :contentReference[oaicite:3]{index=3}
  Future<BigInt> getHolderRawBalance({
    required String contractAddress,
    required String holderAddress,
    int limit = 200,                 // max allowed by API
    int maxPages = 5,                // safety cap; increase if you must
    bool onlyConfirmed = true,
  }) async {
    _ensureAddress(contractAddress);
    _ensureAddress(holderAddress);

    String? fingerprint;
    for (int page = 0; page < maxPages; page++) {
      final qs = [
        if (onlyConfirmed) 'only_confirmed=true',
        'order_by=balance,desc',
        'limit=$limit',
        if (fingerprint != null) 'fingerprint=$fingerprint',
      ].join('&');

      final uri = Uri.parse(
        '${_cfg.baseUrl}/v1/contracts/$contractAddress/tokens?$qs',
      );

      final resp = await _get(uri);
      final json = _safeJson(resp);

      final List data = (json['data'] as List?) ?? const [];
      for (final row in data) {
        final m = (row as Map).cast<String, dynamic>();
        if ((m['address'] ?? '') == holderAddress) {
          final balStr = (m['balance'] ?? '0').toString();
          return BigInt.tryParse(balStr) ?? BigInt.zero;
        }
      }

      final meta = (json['meta'] as Map?) ?? const {};
      fingerprint = meta['fingerprint']?.toString();
      if (fingerprint == null || data.isEmpty) break; // no more pages
    }
    return BigInt.zero; // not found (likely zero balance or low-ranked holder)
  }

  /// Public: Get a wallet’s USDT (or any TRC20) balance using the *holders* endpoint.
  /// Returns human units (double), fetching token decimals automatically.
  Future<double> getTrc20BalanceViaHolders({
    required String walletBase58,
    String contractAddress = USDT_TRC20_MAINNET,  // override with USDT_TRC20_SHASTA on Shasta
    int pageLimit = 200,
    int maxPages = 5,
  }) async {
    _ensureAddress(walletBase58);
    final raw = await getHolderRawBalance(
      contractAddress: contractAddress,
      holderAddress: walletBase58,
      limit: pageLimit,
      maxPages: maxPages,
      onlyConfirmed: true,
    );
    if (raw == BigInt.zero) return 0.0;
    final decimals = await getTrc20Decimals(contractAddress);
    return raw.toDouble() / pow10(decimals);
  }

  /// Mixed (TRX + TRC20) raw tx list (normalized minimal view)
  Future<List<Map<String, dynamic>>> getTransactionHistory(
      String base58Address, {
        int limit = 20,
        int start = 0,
        String sort = '-timestamp',
      }) async {
    _ensureAddress(base58Address);
    if (limit <= 0 || limit > 200) throw TronError('limit must be 1..200');
    final uri = Uri.parse(
        '${_cfg.baseUrl}/v1/accounts/$base58Address/transactions?limit=$limit&start=$start&sort=$sort');
    final resp = await _get(uri);
    final body = _safeJson(resp);
    final List txs = body['data'] ?? [];
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

  /* ====================== Estimation / Simulation ====================== */

  Future<Map<String, dynamic>> estimateUsdtTransfer({
    required String fromAddress,
    required String toAddress,
    required double amount,
    String contractAddress = USDT_TRC20_MAINNET,
    int permissionId = 0,
    double safetyMultiplier = 1.25,
  }) async {
    _ensureAddress(fromAddress);
    _ensureAddress(toAddress);
    _ensureAddress(contractAddress);
    if (permissionId == 1) {
      throw TronError('permission_id 1 (witness) is invalid for transactions');
    }
    if (amount <= 0) throw TronError('Amount must be > 0');

    final amountInteger = (amount * 1e6).round();
    final toHex20 = tronBase58ToHex20(toAddress);
    final paramsHex = _abiEncodeTransfer(toHex20, amountInteger);

    // Try /wallet/estimateenergy
    int? energyRequired;
    bool? estimateOk;
    try {
      final uri = Uri.parse('${_cfg.baseUrl}/wallet/estimateenergy');
      final res = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'owner_address': fromAddress,
          'contract_address': contractAddress,
          'function_selector': 'transfer(address,uint256)',
          'parameter': paramsHex,
          'visible': true,
          if (permissionId != 0) 'permission_id': permissionId,
        }),
      ).timeout(_cfg.timeout);
      final j = _safeJson(res);
      energyRequired = (j['energy_required'] as num?)?.toInt();
      estimateOk = j['result']?['result'] == true;
    } catch (_) {/* ignore */ }

    // Fallback: /wallet/triggerconstantcontract
    int? energyUsed;
    int? energyPenalty;
    bool? willSucceed;
    String? readableMsg;
    try {
      final uri = Uri.parse('${_cfg.baseUrl}/wallet/triggerconstantcontract');
      final res = await _http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'owner_address': fromAddress,
          'contract_address': contractAddress,
          'function_selector': 'transfer(address,uint256)',
          'parameter': paramsHex,
          'call_value': 0,
          'visible': true,
          if (permissionId != 0) 'permission_id': permissionId,
        }),
      ).timeout(_cfg.timeout);
      final j = _safeJson(res);
      willSucceed = j['result']?['result'] == true;
      energyUsed = (j['energy_used'] as num?)?.toInt();
      energyPenalty = (j['energy_penalty'] as num?)?.toInt();
      final msg = j['message'];
      if (msg is String) {
        readableMsg = _decodeB64OrText(msg);
      }
      energyRequired ??= energyUsed;
    } catch (_) {/* ignore */ }

    if (energyRequired == null && energyUsed == null) {
      throw TronError('Unable to estimate energy on this node');
    }

    final unitPriceSun = await _getEnergyUnitPriceSun(); // SUN per energy unit
    final energy = (energyRequired ?? energyUsed!) + (energyPenalty ?? 0);
    final feeLimitSun = (energy * unitPriceSun * safetyMultiplier).ceil();

    return {
      'energy_used': energyUsed,
      'energy_penalty': energyPenalty,
      'energy_required': energyRequired,
      'energy_unit_price_sun': unitPriceSun,
      'recommended_fee_limit_sun': feeLimitSun,
      'will_succeed': estimateOk ?? willSucceed ?? false,
      'raw': {
        'estimateenergy_ok': estimateOk,
        'will_succeed': willSucceed,
        'message': readableMsg,
      }
    };
  }

  /* ---------------- Sends w/ Balance + OUT_OF_ENERGY guards ---------------- */

  Future<String> sendTrx({
    required Uint8List privateKey,
    required String toAddress,
    required int amountSun,            // 1 TRX = 1_000_000 SUN
    int permissionId = 0,
    int minFeeBufferSun = 100_000,     // ~0.1 TRX buffer
  }) async {
    _ensureAddress(toAddress);
    if (permissionId == 1) {
      throw TronError('permission_id 1 (witness) is invalid for transactions');
    }
    if (amountSun <= 0) throw TronError('Amount must be > 0');

    final owner = tronAddressFromPrivateKey(privateKey);

    // Balance guard: require amount + buffer
    final trxBal = await getTrxBalance(owner);
    final need = amountSun + (minFeeBufferSun > 0 ? minFeeBufferSun : 0);
    if (trxBal < need) {
      throw TronError(
        'Insufficient TRX balance. Need at least ${need} SUN (amount + buffer), have $trxBal.',
      );
    }

    // 1) Build
    final buildUri = Uri.parse('${_cfg.baseUrl}/wallet/createtransaction');
    final buildRes = await _http.post(
      buildUri,
      headers: _headers(),
      body: jsonEncode({
        'to_address': toAddress,
        'owner_address': owner,
        'amount': amountSun,
        'visible': true,
        if (permissionId != 0) 'permission_id': permissionId,
      }),
    ).timeout(_cfg.timeout);
    final tx = _extractTxOrThrow(_safeJson(buildRes));
    if (permissionId != 0) tx['permission_id'] = permissionId;

    // 2) Sign
    final signed = _signTransaction(tx, privateKey);

    // 3) Broadcast
    return _broadcast(signed);
  }

  Future<String> sendUsdt({
    required Uint8List privateKey,
    required String toAddress,
    required double amount,
    String contractAddress = USDT_TRC20_MAINNET,
    int feeLimitSun = 5_000_000,   // auto-raised by estimate if needed
    int permissionId = 0,
    bool requirePreflightSuccess = true,
  }) async {
    _ensureAddress(toAddress);
    _ensureAddress(contractAddress);
    if (permissionId == 1) {
      throw TronError('permission_id 1 (witness) is invalid for transactions');
    }
    if (amount <= 0) throw TronError('Amount must be > 0');

    final owner = tronAddressFromPrivateKey(privateKey);

    // 1) USDT balance guard
    final usdtBal = await getTrc20BalanceViaHolders( walletBase58: contractAddress);
    if (usdtBal + 1e-9 < amount) {
      throw TronError('Insufficient USDT: need $amount, have ${usdtBal.toStringAsFixed(6)}');
    }

    // 2) Preflight estimate
    int finalFeeLimit = feeLimitSun;
    try {
      final est = await estimateUsdtTransfer(
        fromAddress: owner,
        toAddress: toAddress,
        amount: amount,
        contractAddress: contractAddress,
        permissionId: permissionId,
      );
      final rec = est['recommended_fee_limit_sun'] as int?;
      final will = est['will_succeed'] == true;
      if (rec != null && rec > finalFeeLimit) finalFeeLimit = rec;
      if (requirePreflightSuccess && !will) {
        final msg = (est['raw'] as Map?)?['message'];
        throw TronError(
          'Preflight indicates failure (likely OUT_OF_ENERGY or revert). '
              'Increase fee_limit or check balances/allowances. '
              'Node message: ${msg ?? 'N/A'}',
        );
      }
    } catch (e) {
      _log?.call('estimateUsdtTransfer failed: $e — proceeding with fee_limit=$finalFeeLimit');
    }

    // 3) TRX balance guard (for energy burn)
    final trxBal = await getTrxBalance(owner);
    if (trxBal < finalFeeLimit) {
      throw TronError(
        'Insufficient TRX to cover Energy burn. Need at least $finalFeeLimit SUN for fee_limit, have $trxBal.',
      );
    }

    // Build
    final amountInteger = (amount * 1e6).round();
    final toHex20 = tronBase58ToHex20(toAddress);
    final param = _abiEncodeTransfer(toHex20, amountInteger);

    final buildUri = Uri.parse('${_cfg.baseUrl}/wallet/triggersmartcontract');
    final buildRes = await _http.post(
      buildUri,
      headers: _headers(),
      body: jsonEncode({
        'owner_address': owner,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': param,
        'fee_limit': finalFeeLimit,
        'call_value': 0,
        'visible': true,
        if (permissionId != 0) 'permission_id': permissionId,
      }),
    ).timeout(_cfg.timeout);

    final body = _safeJson(buildRes);
    if (body['result'] != true && body['transaction'] == null) {
      final msg = body['message'] is String ? _decodeB64OrText(body['message']) : '${body['message']}';
      throw TronError('Trigger failed: $msg');
    }
    final tx = _extractTxOrThrow(body);
    if (permissionId != 0) tx['permission_id'] = permissionId;

    // Sign
    final signed = _signTransaction(tx, privateKey);

    // Broadcast
    return _broadcast(signed);
  }

  /* ---------------- WebSocket (optional) ---------------- */

  Stream<Map<String, dynamic>> subscribeIncomingTransactions(String address) async* {
    _ensureAddress(address);
    const url = 'wss://api.trongrid.io/v1/transactions/subscribe';
    _log?.call('WS connecting: $url');

    late WebSocket socket;
    try {
      socket = await WebSocket.connect(url);
      socket.add(jsonEncode({'event': 'subscribe', 'address': address}));
    } catch (e) {
      throw TronError('WebSocket connection failed', inner: e);
    }

    final controller = StreamController<Map<String, dynamic>>();
    socket.listen((raw) {
      try {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        controller.add(msg);
      } catch (e) {
        _log?.call('WS parse error: $e');
      }
    }, onError: (e) {
      controller.addError(TronError('WS error', inner: e));
    }, onDone: () {
      controller.close();
    });

    yield* controller.stream;
  }

  /* ---------------- HTTP helpers ---------------- */

  Future<http.Response> _get(Uri uri) => _withRetry(() {
    _log?.call('GET $uri');
    return _http.get(uri, headers: _headers()).timeout(_cfg.timeout);
  });

  Future<String> _broadcast(Map<String, dynamic> signedTx) async {
    final bcUri = Uri.parse('${_cfg.baseUrl}/wallet/broadcasttransaction');
    final bcRes = await _http
        .post(bcUri, headers: _headers(), body: jsonEncode(signedTx))
        .timeout(_cfg.timeout);
    final resp = _safeJson(bcRes);

    if (resp['result'] == true) {
      return (signedTx['txID'] as String?) ?? (resp['txid'] as String? ?? '');
    }

    String msg = '${resp['message'] ?? resp['code'] ?? resp}';
    msg = _decodeB64OrText(msg);
    final code = (resp['code'] as String?)?.toUpperCase() ?? '';
    final upperMsg = msg.toUpperCase();
    if (code.contains('OUT_OF_ENERGY') || upperMsg.contains('OUT_OF_ENERGY') || upperMsg.contains('OUT OF ENERGY')) {
      throw TronError('OUT_OF_ENERGY: $msg', status: bcRes.statusCode);
    }
    throw TronError('Broadcast failed: $msg', status: bcRes.statusCode);
  }

  Map<String, dynamic> _extractTxOrThrow(Map<String, dynamic> body) {
    final tx = body['transaction'] ?? body;
    if (tx is Map && tx['raw_data_hex'] != null) return Map<String, dynamic>.from(tx);
    throw TronError('Unexpected build response: missing transaction/raw_data_hex');
  }

  Map<String, String> _headers() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_cfg.tronProApiKey?.isNotEmpty == true) 'TRON-PRO-API-KEY': _cfg.tronProApiKey!,
  };

  Future<T> _withRetry<T>(Future<T> Function() run) async {
    TronError? last;
    for (var attempt = 0; attempt <= _cfg.maxRetries; attempt++) {
      try {
        final res = await run();
        if (res is http.Response) {
          if (res.statusCode >= 200 && res.statusCode < 300) return res;
          if (res.statusCode == 429 || (res.statusCode >= 500 && res.statusCode < 600)) {
            last = TronError('HTTP ${res.statusCode}: ${res.body}', status: res.statusCode);
          } else {
            throw TronError('HTTP ${res.statusCode}: ${res.body}', status: res.statusCode);
          }
        } else {
          return res;
        }
      } catch (e) {
        final isTransient = e is SocketException || e is TimeoutException;
        if (!isTransient) rethrow;
        last = TronError('Transient error: $e', inner: e);
      }
      final waitMs = 200 * (1 << attempt);
      _log?.call('Retrying in ${waitMs}ms...');
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    throw last ?? TronError('Request failed');
  }

  Map<String, dynamic> _safeJson(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw TronError('Invalid JSON response', status: r.statusCode, inner: e);
    }
  }

  /* ---------------- Signing & Encoding utils ---------------- */

  /// Sign a transaction using web3dart (secp256k1). Produces 65-byte r||s||v (v=27/28).
  Map<String, dynamic> _signTransaction(Map<String, dynamic> tx, Uint8List privateKey) {
    final rawHex = tx['raw_data_hex'] as String?;
    if (rawHex == null || rawHex.isEmpty) {
      throw TronError('Transaction missing raw_data_hex');
    }

    // Tron uses sha256(raw_data) for signing
    final rawBytes = conv.hex.decode(rawHex);
    final hash = dart_crypto.sha256.convert(rawBytes).bytes;
    final msg = Uint8List.fromList(hash);

    final web3.MsgSignature sig = web3.sign(msg, privateKey);
    final rHex = sig.r.toRadixString(16).padLeft(64, '0'); // BigInt -> hex
    final sHex = sig.s.toRadixString(16).padLeft(64, '0'); // BigInt -> hex
    final v = (sig.v == 27 || sig.v == 28) ? sig.v : (27 + (sig.v % 2)); // ensure 27/28
    final vHex = v.toRadixString(16).padLeft(2, '0');

    final sigHex = '$rHex$sHex$vHex';

    final out = Map<String, dynamic>.from(tx);
    final List sigs = (out['signature'] as List?)?.toList() ?? <String>[];
    sigs.add(sigHex);
    out['signature'] = sigs;
    return out;
  }

  /// Current energy unit price (SUN) from chain parameters (key: getEnergyFee).
  Future<int> _getEnergyUnitPriceSun() async {
    final uri = Uri.parse('${_cfg.baseUrl}/wallet/getchainparameters');
    final resp = await _get(uri);
    final j = _safeJson(resp);
    final list = (j['chainParameter'] as List?) ?? const [];
    for (final e in list) {
      if (e is Map && e['key'] == 'getEnergyFee') {
        return (e['value'] as num).toInt();
      }
    }
    return 420; // conservative fallback
  }

  static String _decodeB64OrText(String s) {
    try {
      return utf8.decode(base64Decode(s));
    } catch (_) {
      return s;
    }
  }

  void _ensureAddress(String addr) {
    if (addr.isEmpty) throw TronError('Address is empty');
    if (!RegExp(r'^[Tt][a-zA-Z0-9]{25,36}$').hasMatch(addr)) {
      _log?.call('Warning: address format looks unusual: $addr');
    }
  }

  /* ---------------- Base58 / ABI utils ---------------- */

  /// Tron base58 -> 21-byte payload hex ("41" + 20-byte address)
  static String tronBase58ToHex(String base58) {
    final full = _base58Decode(base58);
    if (full.length < 5) throw TronError('Invalid Base58Check address');
    final payload = full.sublist(0, full.length - 4);
    // verify checksum
    final d1 = dart_crypto.sha256.convert(payload).bytes;
    final d2 = dart_crypto.sha256.convert(d1).bytes;
    final expected = d2.sublist(0, 4);
    final got = full.sublist(full.length - 4);
    for (var i = 0; i < 4; i++) {
      if (expected[i] != got[i]) throw TronError('Bad Base58Check checksum');
    }
    return conv.hex.encode(payload);
  }

  /// Tron base58 -> 20-byte hex for ABI (drop leading 0x41)
  static String tronBase58ToHex20(String base58) {
    final hex41 = tronBase58ToHex(base58);
    if (!hex41.startsWith('41') || hex41.length != 42) {
      throw TronError('Expected Tron hex with 0x41 prefix');
    }
    return hex41.substring(2);
  }

  /// ABI encode `transfer(address,uint256)` parameters
  static String _abiEncodeTransfer(String addressHex20, int amountInteger) {
    final a = addressHex20.toLowerCase().replaceAll(RegExp(r'^0x'), '');
    if (a.length != 40) {
      throw TronError('Address hex must be 20 bytes (40 hex chars)');
    }
    final amountHex = amountInteger.toRadixString(16);
    final wAddress = a.padLeft(64, '0');
    final wAmount = amountHex.padLeft(64, '0');
    return '$wAddress$wAmount';
  }

  static const _B58_ALPHABET =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _base58Encode(Uint8List bytes) {
    final hexStr = conv.hex.encode(bytes);
    var intData = BigInt.parse(hexStr, radix: 16);
    final modBase = BigInt.from(58);
    var out = '';
    while (intData > BigInt.zero) {
      final mod = intData % modBase;
      out = _B58_ALPHABET[mod.toInt()] + out;
      intData = intData ~/ modBase;
    }
    for (var i = 0; i < bytes.length && bytes[i] == 0; i++) {
      out = '1$out';
    }
    return out;
  }

  static Uint8List _base58Decode(String input) {
    BigInt intData = BigInt.zero;
    for (var rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final p = _B58_ALPHABET.indexOf(ch);
      if (p < 0) throw TronError('Invalid Base58 character: $ch');
      intData = intData * BigInt.from(58) + BigInt.from(p);
    }
    var hexStr = intData.toRadixString(16);
    if (hexStr.length % 2 == 1) hexStr = '0$hexStr';
    var bytes = Uint8List.fromList(conv.hex.decode(hexStr));
    var leadingZeros = 0;
    for (var i = 0; i < input.length && input[i] == '1'; i++) {
      leadingZeros++;
    }
    if (leadingZeros > 0) {
      bytes = Uint8List.fromList([...List.filled(leadingZeros, 0), ...bytes]);
    }
    return bytes;
  }

  static String _base58CheckEncode(Uint8List payload) {
    final d1 = dart_crypto.sha256.convert(payload).bytes;
    final d2 = dart_crypto.sha256.convert(d1).bytes;
    final checksum = Uint8List.fromList(d2.sublist(0, 4));
    final full = Uint8List.fromList([...payload, ...checksum]);
    return _base58Encode(full);
  }

  /* ====================== Transaction normalization (UI-ready) ====================== */
  /// Unified transaction model for UI.
  /// Each map contains:
  /// {
  ///   id: String,
  ///   timestamp: int (ms),
  ///   asset: String ('TRX' | 'USDT' | 'TRC20'),
  ///   amount: double,  // human units
  ///   from: String,    // Base58
  ///   to: String,      // Base58
  ///   direction: String ('in' | 'out' | 'other'),
  ///   raw: Map<String, dynamic> // the original tx (normalized core fields)
  /// }
  Future<List<Map<String, dynamic>>> getUnifiedTransactions(
      String myBase58Address, {
        int limit = 20,
        int start = 0,
      }) async {
    _ensureAddress(myBase58Address);

    final raw = await getTransactionHistory(
      myBase58Address,
      limit: limit,
      start: start,
      sort: '-timestamp',
    );

    final List<Map<String, dynamic>> out = [];
    for (final tx in raw) {
      try {
        final ts = (tx['timestamp'] as num?)?.toInt();
        final id = tx['txID']?.toString() ?? '';
        final type = tx['type']?.toString() ?? '';
        final contract = (tx['contract'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

        // Common fields we try to extract for every tx:
        String fromB58 = '';
        String toB58 = '';
        String asset = 'TRX';
        double amount = 0.0;

        if (type == 'TransferContract') {
          // Native TRX transfer
          final fromHex41 = (contract['owner_address'] ?? '').toString();
          final toHex41 = (contract['to_address'] ?? '').toString();
          final amtSun = (contract['amount'] is num) ? (contract['amount'] as num).toInt() : int.tryParse('${contract['amount']}') ?? 0;
          fromB58 = _addrToBase58(fromHex41);
          toB58 = _addrToBase58(toHex41);
          asset = 'TRX';
          amount = amtSun / 1e6;
        } else if (type == 'TriggerSmartContract') {
          // Smart-contract call; detect ERC-20 transfer(address,uint256)
          final ownerHex41 = (contract['owner_address'] ?? '').toString();
          fromB58 = _addrToBase58(ownerHex41);

          // Contract address can be Base58 or Hex41 depending on node
          String contractAddrRaw = (contract['contract_address'] ?? '').toString();
          final contractB58 = _addrToBase58(contractAddrRaw);

          final dataHex = _sanitizeHex((contract['data'] ?? '').toString());
          if (dataHex.length >= 8 + 64 + 64 && dataHex.startsWith('a9059cbb')) {
            // ERC-20 transfer(selector a9059cbb)
            final addrSlot = dataHex.substring(8, 8 + 64);
            final valueSlot = dataHex.substring(8 + 64, 8 + 64 + 64);

            final to20 = addrSlot.substring(24); // last 40 chars (20 bytes)
            final toHex41 = '41$to20';
            toB58 = _addrToBase58(toHex41);

            final value = BigInt.parse(valueSlot, radix: 16);
            // Assume USDT (6 dp) if calling the USDT contract, else default 6 dp.
            final isUSDT = contractB58 == USDT_TRC20_MAINNET;
            final decimals = isUSDT ? 6 : 6;
            asset = isUSDT ? 'USDT' : 'TRC20';
            amount = value.toDouble() / (pow10(decimals));
          } else {
            // Not an ERC-20 transfer; fallback to generic display
            toB58 = contractB58;
            asset = 'TRC20';
            amount = 0.0;
          }
        } else {
          // Other contract types — show as generic; try addresses if present
          final fromHex41 = (contract['owner_address'] ?? '').toString();
          final toHex41 = (contract['to_address'] ?? '').toString();
          fromB58 = _addrToBase58(fromHex41);
          toB58 = _addrToBase58(toHex41);
          asset = 'TRX';
          amount = 0.0;
        }

        final dir = (toB58 == myBase58Address)
            ? 'in'
            : (fromB58 == myBase58Address ? 'out' : 'other');

        out.add({
          'id': id,
          'timestamp': ts ?? 0,
          'asset': asset,
          'amount': amount,
          'from': fromB58,
          'to': toB58,
          'direction': dir,
          'raw': tx,
        });
      } catch (_) {
        // swallow malformed tx
      }
    }

    return out;
  }

  // --------------- Small helpers for normalization ---------------

  // power-of-10 as double to avoid using toRadixString on doubles
  static double pow10(int n) {
    double x = 1.0;
    for (int i = 0; i < n; i++) x *= 10.0;
    return x;
  }

  /// Accepts Base58 ("T...") or Hex41 ("41...") and returns Base58 if possible.
  static String _addrToBase58(String maybeHexOrB58) {
    if (maybeHexOrB58.isEmpty) return '';
    if (RegExp(r'^[Tt][A-Za-z0-9]{25,36}$').hasMatch(maybeHexOrB58)) {
      return maybeHexOrB58;
    }
    final h = _sanitizeHex(maybeHexOrB58);
    if (h.length == 42 && h.startsWith('41')) {
      try {
        final payload = Uint8List.fromList(conv.hex.decode(h));
        return _base58CheckEncode(payload); // already 0x41 + 20B
      } catch (_) {
        return maybeHexOrB58;
      }
    }
    return maybeHexOrB58;
  }

  static String _sanitizeHex(String s) {
    final t = s.startsWith('0x') || s.startsWith('0X') ? s.substring(2) : s;
    return t.toLowerCase();
  }

  // ── NEW: Stream watcher for *incoming* transactions only ────────────────
  Stream<Map<String, dynamic>> watchIncoming(
      String address, {
        Duration interval = const Duration(seconds: 12),
        int pageLimit = 20,
      }) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final seen = <String>{}; // track tx IDs we've already emitted
    Timer? timer;
    bool isFetching = false;

    Future<void> _tick() async {
      if (isFetching) return;
      isFetching = true;
      try {
        final batch = await getUnifiedTransactions(address, limit: pageLimit, start: 0);
        // only IN transactions to this address
        final incoming = batch.where((t) => (t['direction']?.toString() ?? '') == 'in');

        // newest first, but emit oldest first for natural order
        final newOnes = incoming.where((t) => !seen.contains('${t['id']}')).toList()
          ..sort((a, b) {
            final ta = (a['timestamp'] as num?)?.toInt() ?? 0;
            final tb = (b['timestamp'] as num?)?.toInt() ?? 0;
            return ta.compareTo(tb);
          });

        for (final tx in newOnes) {
          final id = '${tx['id']}';
          seen.add(id);
          controller.add(tx);
        }

        // keep seen set bounded
        if (seen.length > 2000) {
          // simple pruning—keeps memory tight for long sessions
          seen.removeWhere((_) => seen.length > 1500);
        }
      } catch (e, _) {
        // swallow errors to keep stream alive; consumers can handle UI
      } finally {
        isFetching = false;
      }
    }

    // initial prime + schedule
    _tick();
    timer = Timer.periodic(interval, (_) => _tick());

    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };

    return controller.stream;
  }
}
