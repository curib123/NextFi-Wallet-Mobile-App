// lib/Services/stellar/stellar_wallet_services.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Services/profit_address_vault_secure_storage.dart';

// ========== Helper models ==========

class AccountState {
  final double xlm;
  final double usdc;
  final bool hasUsdcTrustline;
  final DateTime updatedAt;
  const AccountState({
    required this.xlm,
    required this.usdc,
    required this.hasUsdcTrustline,
    required this.updatedAt,
  });
}

class FeeEstimate {
  final int perOpStroops;
  final int totalStroops;
  final double totalXlm;
  final int baseFee;
  final int opCount;
  final int percentile;
  final DateTime ledgerClosedAt;
  const FeeEstimate({
    required this.perOpStroops,
    required this.totalStroops,
    required this.totalXlm,
    required this.baseFee,
    required this.opCount,
    required this.percentile,
    required this.ledgerClosedAt,
  });
}

class PairPrice {
  final double usdcPerXlm; // counter/base = USDC per 1 XLM
  double get xlmPerUsdc => usdcPerXlm == 0 ? 0 : 1 / usdcPerXlm;
  final DateTime at;
  const PairPrice(this.usdcPerXlm, this.at);
}

// ========== Minimal Soroban JSON-RPC client (fallback only) ==========
// SOROBAN
class _SorobanRpc {
  final String base; // e.g. https://rpc.ankr.com/stellar_soroban
  final Map<String, String>? headers;
  _SorobanRpc(this.base, [this.headers]);

  Future<Map<String, dynamic>?> _rpc(
      String method, {
        Object? params,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final uri = Uri.parse(base);
    final payload = json.encode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params ?? {},
    });
    final resp = await http
        .post(
      uri,
      headers: {
        'content-type': 'application/json',
        if (headers != null) ...headers!,
      },
      body: payload,
    )
        .timeout(timeout);
    if (resp.statusCode != 200) return null;
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['error'] != null) return null;
    return j['result'] as Map<String, dynamic>?;
  }

  Future<String?> sendTransaction(String envelopeB64) async {
    final r = await _rpc('sendTransaction', params: {'transaction': envelopeB64});
    // result: { hash, status, latestLedger, latestLedgerCloseTime, ... }
    return (r?['hash'] as String?);
  }

  Future<int?> getLatestLedgerSequence() async {
    final r = await _rpc('getLatestLedger');
    final n = r?['sequence'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return null;
  }
}

// ========== StellarWalletService ==========

class StellarWalletService {
  // Primary SDK (SDF Horizon)
  final StellarSDK sdk;

  // QuickNode Horizon fallback (optional)
  final String? quickNodeUrlMainnet;
  final String? quickNodeUrlTestnet;
  final Map<String, String>? quickNodeDefaultHeaders;
  final StellarSDK? _sdkQuickNode;

  // Soroban JSON-RPC fallback (optional) — used for sendTransaction + ledger hints
  final String? sorobanUrlMainnet;
  final String? sorobanUrlTestnet;
  final Map<String, String>? sorobanDefaultHeaders;
  final _SorobanRpc? _soroban;

  final TransactionFeeVaultSecureStorage configVault;

  static const String _DEFAULT_USDC_ISSUER_MAINNET =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  static const String _DEFAULT_USDC_ISSUER_TESTNET =
      'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

  final String? usdcIssuerOverrideMainnet;
  final String? usdcIssuerOverrideTestnet;

  StellarWalletService({
    bool testnet = false,
    this.usdcIssuerOverrideMainnet,
    this.usdcIssuerOverrideTestnet,
    TransactionFeeVaultSecureStorage? configVault,

    // QuickNode Horizon
    this.quickNodeUrlMainnet,
    this.quickNodeUrlTestnet,
    this.quickNodeDefaultHeaders,

    // Soroban JSON-RPC
    this.sorobanUrlMainnet,
    this.sorobanUrlTestnet,
    this.sorobanDefaultHeaders,
  })  : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
        _sdkQuickNode = (() {
          final url = testnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;
          return (url != null && url.isNotEmpty) ? StellarSDK(url) : null;
        })(),
        _soroban = (() {
          final url = testnet ? sorobanUrlTestnet : sorobanUrlMainnet;
          return (url != null && url.isNotEmpty) ? _SorobanRpc(url, sorobanDefaultHeaders) : null;
        })(),
        configVault = configVault ?? const TransactionFeeVaultSecureStorage();

  bool get _isTestnet => identical(sdk, StellarSDK.TESTNET);
  Network get _network => _isTestnet ? Network.TESTNET : Network.PUBLIC;

  Asset get _xlm => Asset.NATIVE;

  String get _usdcIssuer => _isTestnet
      ? (usdcIssuerOverrideTestnet ?? _DEFAULT_USDC_ISSUER_TESTNET)
      : (usdcIssuerOverrideMainnet ?? _DEFAULT_USDC_ISSUER_MAINNET);

  Asset get _usdc => AssetTypeCreditAlphaNum4('USDC', _usdcIssuer);

  static String _fmt7(num v) => v.toStringAsFixed(7);

  static Never _fail(String message, [Object? inner]) {
    throw Exception(inner == null ? message : '$message (inner: $inner)');
  }

  // Primary Horizon base (public)
  String get horizonBase =>
      _isTestnet ? 'https://horizon-testnet.stellar.org' : 'https://horizon.stellar.org';

  // QuickNode base (fallback), if configured
  String? get _qnBase => _isTestnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;

  // ===== HTTP helper with SDF ➜ QuickNode fallback (Soroban can’t serve Horizon REST) =====
  Future<http.Response> _getWithFallback(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    // 1) Try SDF Horizon
    final primary = Uri.parse('$horizonBase$path').replace(queryParameters: query);
    try {
      final r = await http.get(primary).timeout(timeout);
      if (r.statusCode == 200) return r;

      // If outage/429/5xx —> QuickNode Horizon
      if (r.statusCode == 429 || (r.statusCode >= 500 && r.statusCode <= 599)) {
        final fr = await _tryQuickNode(path, query: query, timeout: timeout);
        if (fr != null) return fr;
      }
      return r;
    } catch (_) {
      // network/timeout —> QuickNode
      final fr = await _tryQuickNode(path, query: query, timeout: timeout);
      if (fr != null) return fr;
      rethrow;
    }
  }

  Future<http.Response?> _tryQuickNode(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final base = _qnBase;
    if (base == null || base.isEmpty) return null;
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    try {
      return await http.get(uri, headers: quickNodeDefaultHeaders).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  // ===== Basics =====

  static Future<String> generateMnemonic() => Wallet.generate24WordsMnemonic();
  static Future<Wallet> walletFromMnemonic(String mnemonic) => Wallet.from(mnemonic);
  static Future<KeyPair> getKeyPair(Wallet wallet, {int index = 0}) => wallet.getKeyPair(index: index);

  Future<AccountResponse> _loadAccount(String accountId) =>
      sdk.accounts.account(accountId);

  bool get isTestnet => _isTestnet;
  String get usdcIssuer => _usdcIssuer;

  Future<String> getTransactionFeeAddress() async =>
      (await configVault.readOrInit()).address;

  Future<int> getCurrentFeeStroops() async =>
      (await configVault.readOrInit()).feeStroops;

  Future<double> getCurrentFeeXlm() async =>
      (await configVault.readOrInit()).feeXlm;

  Future<String> getCurrentFeeLabel() async =>
      (await configVault.readOrInit()).feeXlmLabel;

  @Deprecated('Use getTransactionFeeAddress() instead.')
  Future<String> getProfitAddress() => getTransactionFeeAddress();

  @Deprecated('Fixed-fee mode: use getCurrentFeeXlm() / getCurrentFeeStroops() instead.')
  Future<int> getCurrentFeeBps() async => 0;

  int _toStroops(double amount) => (amount * 1e7).round();
  double _fromStroops(int stroops) => stroops / 1e7;

  // ===== Balances =====

  Future<double> getXlmBalance(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) return double.parse(b.balance);
      }
      return 0.0;
    } catch (e) {
      _fail('Failed to fetch XLM balance', e);
    }
  }

  Future<double> getUsdcBalance(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer) {
          return double.parse(b.balance);
        }
      }
      return 0.0;
    } catch (e) {
      _fail('Failed to fetch USDC balance', e);
    }
  }

  // ===== Trustlines =====

  Future<bool> hasUsdcTrustline(String accountId) async {
    final acc = await _loadAccount(accountId);
    return acc.balances.any((b) => b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer);
  }

  Future<String> createUsdcTrustline({
    required String secretSeed,
    String limit = '922337203685.4775807',
  }) async {
    try {
      final kp = KeyPair.fromSecretSeed(secretSeed);
      final acc = await _loadAccount(kp.accountId);

      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(_usdc, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(kp, _network);

      // Submit: SDF ➜ Soroban ➜ QuickNode
      try {
        final res = await sdk.submitTransaction(tx);
        if (!res.success) _fail('ChangeTrust(USDC) failed: ${res.resultXdr}');
        return res.hash!;
      } catch (_) {
        // SOROBAN fallback
        final hash = await _trySorobanSend(tx);
        if (hash != null) return hash;

        // QuickNode fallback
        if (_sdkQuickNode != null) {
          final res = await _sdkQuickNode.submitTransaction(tx);
          if (!res.success) _fail('ChangeTrust(USDC) failed on QuickNode: ${res.resultXdr}');
          return res.hash!;
        }
        rethrow;
      }
    } catch (e) {
      _fail('Failed to create USDC trustline', e);
    }
  }

  // SOROBAN: best-effort broadcast using JSON-RPC sendTransaction
  Future<String?> _trySorobanSend(Transaction tx) async {
    if (_soroban == null) return null;
    try {
      // NOTE: If your SDK uses a different name, change accordingly:
      final envelopeB64 = tx.toEnvelopeXdrBase64(); // common in stellar_flutter_sdk
      final hash = await _soroban.sendTransaction(envelopeB64);
      return hash;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureUsdcTrustlineSelf(String secretSeed, {String limit = '922337203685.4775807'}) async {
    final kp = KeyPair.fromSecretSeed(secretSeed);
    if (await hasUsdcTrustline(kp.accountId)) return;
    await createUsdcTrustline(secretSeed: secretSeed, limit: limit);
  }

  // ===== Payments (fixed transaction fee in XLM; separate from network fee) =====

  Future<List<String>> sendXlmWithFee({
    required String secretSeed,
    required String destination,
    required double amount,
    String? memoText,
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');
    final dest = destination.trim();
    if (dest.isEmpty) _fail('Destination is required');

    final feeAddr = await getTransactionFeeAddress();
    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);

    KeyPair.fromAccountId(dest);
    KeyPair.fromAccountId(feeAddr);
    if (dest == feeAddr) _fail('Destination cannot be the transaction fee address.');

    final totalStroops = _toStroops(amount);
    if (totalStroops <= feeStroops) {
      _fail('Amount too small: must be greater than fixed transaction fee of ${_fmt7(feeXlm)} XLM');
    }
    final recvPart = totalStroops - feeStroops;

    final sender = KeyPair.fromSecretSeed(secretSeed);
    final acc = await _loadAccount(sender.accountId);

    final opCount = feeStroops > 0 ? 2 : 1;
    final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

    final tb = TransactionBuilder(acc)
      ..setMaxOperationFee(perOpStroops)
      ..addOperation(
        PaymentOperationBuilder(dest, _xlm, _fmt7(_fromStroops(recvPart))).build(),
      );

    if (feeStroops > 0) {
      tb.addOperation(
        PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
      );
    }
    if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

    final tx = tb.build();
    tx.sign(sender, _network);

    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('XLM payment failed: ${res.resultXdr}');
      return [res.hash!];
    } catch (_) {
      // Soroban
      final hash = await _trySorobanSend(tx);
      if (hash != null) return [hash];

      // QuickNode
      if (_sdkQuickNode != null) {
        final res = await _sdkQuickNode.submitTransaction(tx);
        if (!res.success) _fail('XLM payment failed on QuickNode: ${res.resultXdr}');
        return [res.hash!];
      }
      rethrow;
    }
  }

  Future<List<String>> sendUsdcWithFee({
    required String secretSeed,
    required String destination,
    required double usdcAmount,
    String? memoText,
  }) async {
    if (usdcAmount <= 0) _fail('usdcAmount must be > 0');
    final dest = destination.trim();
    if (dest.isEmpty) _fail('Destination is required');

    final feeAddr = await getTransactionFeeAddress();
    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);

    KeyPair.fromAccountId(dest);
    KeyPair.fromAccountId(feeAddr);
    if (dest == feeAddr) _fail('Destination cannot be the transaction fee address.');

    if (!await hasUsdcTrustline(dest)) {
      _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
    }

    final sender = KeyPair.fromSecretSeed(secretSeed);
    final acc = await _loadAccount(sender.accountId);

    final senderXlmBal = await getXlmBalance(sender.accountId);
    if (senderXlmBal + 1e-7 < feeXlm) {
      _fail('Insufficient XLM to pay the fixed transaction fee of ${_fmt7(feeXlm)} XLM.');
    }

    final opCount = feeStroops > 0 ? 2 : 1;
    final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

    final tb = TransactionBuilder(acc)
      ..setMaxOperationFee(perOpStroops)
      ..addOperation(
        PaymentOperationBuilder(dest, _usdc, _fmt7(usdcAmount)).build(),
      );

    if (feeStroops > 0) {
      tb.addOperation(
        PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
      );
    }
    if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

    final tx = tb.build();
    tx.sign(sender, _network);

    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('USDC payment failed: ${res.resultXdr}');
      return [res.hash!];
    } catch (_) {
      final hash = await _trySorobanSend(tx);
      if (hash != null) return [hash];

      if (_sdkQuickNode != null) {
        final res = await _sdkQuickNode.submitTransaction(tx);
        if (!res.success) _fail('USDC payment failed on QuickNode: ${res.resultXdr}');
        return [res.hash!];
      }
      rethrow;
    }
  }

  // ===== Swaps (Strict-Send) with fixed XLM transaction fee =====

  Future<String> swapXlmToUsdc({
    required String secretSeed,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
  }) async {
    if (sendAmountXlm <= 0) _fail('sendAmountXlm must be > 0');
    if (minUsdcOut <= 0) _fail('minUsdcOut must be > 0');

    try {
      final kp = KeyPair.fromSecretSeed(secretSeed);
      final dest = (destination?.trim().isNotEmpty == true) ? destination!.trim() : kp.accountId;

      if (!await hasUsdcTrustline(dest)) {
        _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
      }

      final feeAddr = await getTransactionFeeAddress();
      KeyPair.fromAccountId(feeAddr);

      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      final senderXlmBal = await getXlmBalance(kp.accountId);
      if (senderXlmBal + 1e-7 < (sendAmountXlm + feeXlm)) {
        _fail('Insufficient XLM to swap ${_fmt7(sendAmountXlm)} and pay ${_fmt7(feeXlm)} transaction fee.');
      }

      final acc = await _loadAccount(kp.accountId);

      final opCount = feeStroops > 0 ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final opPath = PathPaymentStrictSendOperationBuilder(
        _xlm,
        _fmt7(sendAmountXlm),
        dest,
        _usdc,
        _fmt7(minUsdcOut),
      ).build();

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(perOpStroops)
        ..addOperation(opPath);

      if (feeStroops > 0) {
        tb.addOperation(
          PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
        );
      }
      if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

      final tx = tb.build();
      tx.sign(kp, _network);

      try {
        final res = await sdk.submitTransaction(tx);
        if (!res.success) _fail('PathPaymentStrictSend XLM→USDC failed: ${res.resultXdr}');
        return res.hash!;
      } catch (_) {
        final hash = await _trySorobanSend(tx);
        if (hash != null) return hash;

        if (_sdkQuickNode != null) {
          final res = await _sdkQuickNode.submitTransaction(tx);
          if (!res.success) _fail('PathPaymentStrictSend XLM→USDC failed on QuickNode: ${res.resultXdr}');
          return res.hash!;
        }
        rethrow;
      }
    } catch (e) {
      _fail('Failed to swap XLM→USDC', e);
    }
  }

  Future<String> swapUsdcToXlm({
    required String secretSeed,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
  }) async {
    if (sendAmountUsdc <= 0) _fail('sendAmountUsdc must be > 0');
    if (minXlmOut <= 0) _fail('minXlmOut must be > 0');

    try {
      final kp = KeyPair.fromSecretSeed(secretSeed);
      final self = kp.accountId;
      final dest = (destination?.trim().isNotEmpty == true) ? destination!.trim() : self;

      await _ensureUsdcTrustlineSelf(secretSeed);

      final feeAddr = await getTransactionFeeAddress();
      KeyPair.fromAccountId(feeAddr);

      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      final acc = await _loadAccount(kp.accountId);

      final opCount = feeStroops > 0 ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        if (minXlmOut + 1e-7 < feeXlm) {
          _fail('minXlmOut too small to cover fixed transaction fee of ${_fmt7(feeXlm)} XLM.');
        }

        final opPath = PathPaymentStrictSendOperationBuilder(
          _usdc,
          _fmt7(sendAmountUsdc),
          self,
          _xlm,
          _fmt7(minXlmOut),
        ).build();

        tb
          ..addOperation(opPath)
          ..addOperation(
            PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
          );
      } else {
        final senderXlmBal = await getXlmBalance(self);
        if (senderXlmBal + 1e-7 < feeXlm) {
          _fail('Insufficient XLM to pay fixed transaction fee of ${_fmt7(feeXlm)} XLM for external swap.');
        }

        final opPath = PathPaymentStrictSendOperationBuilder(
          _usdc,
          _fmt7(sendAmountUsdc),
          dest,
          _xlm,
          _fmt7(minXlmOut),
        ).build();

        tb
          ..addOperation(opPath)
          ..addOperation(
            PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
          );
      }

      if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

      final tx = tb.build();
      tx.sign(kp, _network);

      try {
        final res = await sdk.submitTransaction(tx);
        if (!res.success) _fail('PathPaymentStrictSend USDC→XLM failed: ${res.resultXdr}');
        return res.hash!;
      } catch (_) {
        final hash = await _trySorobanSend(tx);
        if (hash != null) return hash;

        if (_sdkQuickNode != null) {
          final res = await _sdkQuickNode.submitTransaction(tx);
          if (!res.success) _fail('PathPaymentStrictSend USDC→XLM failed on QuickNode: ${res.resultXdr}');
          return res.hash!;
        }
        rethrow;
      }
    } catch (e) {
      _fail('Failed to swap USDC→XLM', e);
    }
  }

  // ===== Quotes (Horizon REST: SDF ➜ QuickNode) =====

  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) async {
    String _destAssetToQuery(Asset a) {
      if (a is AssetTypeNative) return 'native';
      if (a is AssetTypeCreditAlphaNum) {
        final code = a.code;
        final issuer = a.issuerId;
        return '$code:$issuer';
      }
      return 'native';
    }

    final destParam = destinationAssets.map(_destAssetToQuery).join(',');

    final qp = <String, String>{
      'source_amount': sourceAmount,
      if (sourceAsset is AssetTypeNative) 'source_asset_type': 'native',
      if (sourceAsset is AssetTypeCreditAlphaNum) ...{
        'source_asset_type': 'credit_alphanum${sourceAsset.code.length}',
        'source_asset_code': sourceAsset.code,
        'source_asset_issuer': sourceAsset.issuerId,
      },
      'destination_assets': destParam,
    };

    try {
      final resp = await _getWithFallback('/paths/strict-send', query: qp, timeout: const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final records = (data['_embedded']?['records'] as List?) ?? const [];
      if (records.isEmpty) return null;

      final String destAmt = records.first['destination_amount'] as String;
      return double.tryParse(destAmt);
    } catch (_) {
      return null;
    }
  }

  Future<double?> quoteXlmToUsdc(double sendAmountXlm) => quoteStrictSend(
    sourceAsset: _xlm,
    sourceAmount: _fmt7(sendAmountXlm),
    destinationAssets: [_usdc],
  );

  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) => quoteStrictSend(
    sourceAsset: _usdc,
    sourceAmount: _fmt7(sendAmountUsdc),
    destinationAssets: [_xlm],
  );

  Future<double> estimateNetworkFeeXlm({int opCount = 1, int percentile = 90}) async {
    final ops = opCount <= 0 ? 1 : opCount;
    try {
      final resp = await _getWithFallback('/fee_stats', timeout: const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;

        final base = int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
        final fc = (data['fee_charged'] as Map?) ?? const {};
        final p = percentile.clamp(10, 99);
        final perTxStroops = int.tryParse('${fc['p$p'] ?? fc['p50'] ?? base}') ?? base;

        var perOpStroops = (perTxStroops / ops).ceil();
        final maxReasonable = base * 50;
        if (perOpStroops < base) perOpStroops = base;
        if (perOpStroops > maxReasonable) perOpStroops = maxReasonable;

        final totalStroops = perOpStroops * ops;
        return totalStroops * 1e-7;
      }
    } catch (_) {}
    return (200 * (opCount <= 0 ? 1 : opCount)) * 1e-7;
  }

  // ===== Federation =====

  Future<FederationResponse> resolveFederationAddress(String stellarAddress) =>
      Federation.resolveStellarAddress(stellarAddress);

  // ===== Streaming (SDF SSE ➜ QN SSE; Soroban polling as last resort for ledgers) =====

  Stream<T> _sseWithFallback<T>(Stream<T> Function(StellarSDK s) build) {
    final controller = StreamController<T>();
    StreamSubscription<T>? sub;
    bool usingQuickNode = false;

    Future<void> _start(StellarSDK s) async {
      sub = build(s).listen(
        controller.add,
        onError: (e, st) async {
          // If public fails, try once on QN
          if (!usingQuickNode && _sdkQuickNode != null) {
            usingQuickNode = true;
            try {
              await sub?.cancel();
            } catch (_) {}
            await _start(_sdkQuickNode);
          } else {
            controller.addError(e, st);
            await controller.close();
          }
        },
        onDone: () async => controller.close(),
      );
    }

    _start(sdk);
    controller.onCancel = () async {
      try {
        await sub?.cancel();
      } catch (_) {}
    };
    return controller.stream;
  }

  Stream<PaymentOperationResponse> paymentsStream(String accountId) {
    Stream<PaymentOperationResponse> _build(StellarSDK s) {
      return s.payments
          .forAccount(accountId)
          .cursor("now")
          .stream()
          .where((resp) => resp is PaymentOperationResponse && resp.transactionSuccessful)
          .cast<PaymentOperationResponse>();
    }
    // Soroban can’t supply PaymentOperationResponse, so we do SDF ➜ QN only.
    return _sseWithFallback<PaymentOperationResponse>(_build);
  }

  Stream<AccountState> accountStateStream(String accountId) {
    final controller = StreamController<AccountState>();
    Timer? coolDown;
    bool closed = false;

    Future<void> emitSnapshot() async {
      if (closed) return;
      try {
        final acc = await _loadAccount(accountId);
        double xlm = 0, usdc = 0;
        bool tl = false;
        for (final b in acc.balances) {
          if (b.assetType == Asset.TYPE_NATIVE) xlm = double.parse(b.balance);
          if (b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer) {
            usdc = double.parse(b.balance);
            tl = true;
          }
        }
        controller.add(AccountState(
          xlm: xlm,
          usdc: usdc,
          hasUsdcTrustline: tl,
          updatedAt: DateTime.now(),
        ));
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    emitSnapshot();

    // SSE (SDF ➜ QN)
    Stream<void> _payStream(StellarSDK s) =>
        s.payments.forAccount(accountId).cursor("now").stream().map((_) => null);
    Stream<void> _effStream(StellarSDK s) =>
        s.effects.forAccount(accountId).cursor("now").stream().map((_) => null);

    final pay = _sseWithFallback<void>(_payStream).listen((_) {
      coolDown?.cancel();
      coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
    }, onError: controller.addError);

    final eff = _sseWithFallback<void>(_effStream).listen((_) {
      coolDown?.cancel();
      coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
    }, onError: controller.addError);

    controller.onCancel = () async {
      closed = true;
      coolDown?.cancel();
      await pay.cancel();
      await eff.cancel();
    };
    return controller.stream;
  }

  Stream<FeeEstimate> feeEstimateStream({int opCount = 1, int percentile = 90}) {
    final controller = StreamController<FeeEstimate>();
    int? lastSorobanLedger; // SOROBAN polling hint

    Future<void> push(DateTime at) async {
      try {
        final x = await estimateNetworkFeeXlm(opCount: opCount, percentile: percentile);

        int base = 100;
        try {
          final resp = await _getWithFallback('/fee_stats', timeout: const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            base = int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
          }
        } catch (_) {}

        final perOp = (x * 1e7 / (opCount <= 0 ? 1 : opCount)).round();
        final total = (x * 1e7).round();
        controller.add(FeeEstimate(
          perOpStroops: perOp,
          totalStroops: total,
          totalXlm: x,
          baseFee: base,
          opCount: opCount <= 0 ? 1 : opCount,
          percentile: percentile.clamp(10, 99),
          ledgerClosedAt: at,
        ));
      } catch (e, st) {
        controller.addError(e, st);
      }
    }

    push(DateTime.now());

    // SSE ledgers (SDF ➜ QN)
    Stream<void> _ledgerStream(StellarSDK s) =>
        s.ledgers.cursor("now").stream().map((_) => null);

    final ledSub = _sseWithFallback<void>(_ledgerStream).listen((_) {
      push(DateTime.now());
    }, onError: controller.addError, onDone: controller.close);

    // SOROBAN: polling fallback (if SSE is flaky anywhere)
    Timer? sorobanTicker;
    if (_soroban != null) {
      sorobanTicker = Timer.periodic(const Duration(seconds: 8), (_) async {
        try {
          final seq = await _soroban.getLatestLedgerSequence();
          if (seq == null) return;
          if (lastSorobanLedger == null || seq > lastSorobanLedger!) {
            lastSorobanLedger = seq;
            await push(DateTime.now());
          }
        } catch (_) {
          // ignore single poll errors
        }
      });
    }

    controller.onCancel = () async {
      sorobanTicker?.cancel();
      await ledSub.cancel();
    };
    return controller.stream;
  }

  // IMPORTANT: Build trades requests on a specific SDK (for SSE fallback)
  TradesRequestBuilder _tradesForPairOn(StellarSDK s, Asset base, Asset counter) {
    String typeOf(Asset a) {
      if (a is AssetTypeNative) return 'native';
      if (a is AssetTypeCreditAlphaNum4) return 'credit_alphanum4';
      if (a is AssetTypeCreditAlphaNum12) return 'credit_alphanum12';
      throw ArgumentError('Unsupported asset type: $a');
    }

    final b = s.trades;
    b.queryParameters['base_asset_type'] = typeOf(base);
    if (base is AssetTypeCreditAlphaNum) {
      b.queryParameters['base_asset_code'] = base.code;
      b.queryParameters['base_asset_issuer'] = base.issuerId;
    }
    b.queryParameters['counter_asset_type'] = typeOf(counter);
    if (counter is AssetTypeCreditAlphaNum) {
      b.queryParameters['counter_asset_code'] = counter.code;
      b.queryParameters['counter_asset_issuer'] = counter.issuerId;
    }
    return b;
  }

  Stream<PairPrice> xlmUsdcPriceStream() {
    Stream<PairPrice> _build(StellarSDK s) {
      return _tradesForPairOn(s, _xlm, _usdc)
          .cursor('now')
          .stream()
          .map((t) {
        double? price;
        final ba = double.tryParse('${t.baseAmount}');
        final ca = double.tryParse('${t.counterAmount}');
        if (ba != null && ba > 0 && ca != null) {
          price = ca / ba; // USDC per XLM
        }
        price ??= double.tryParse('${t.price}');
        if (price != null && price > 0) {
          return PairPrice(price, DateTime.now());
        }
        throw StateError('Invalid trade price');
      });
    }
    // Soroban has no trades SSE; use SDF ➜ QN chain only.
    return _sseWithFallback<PairPrice>(_build);
  }

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      xlmUsdcPriceStream().map((p) => sendAmountXlm * p.usdcPerXlm);

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      xlmUsdcPriceStream().map((p) => sendAmountUsdc * p.xlmPerUsdc);

  @Deprecated('Use paymentsStream(accountId).listen(...) and cancel on dispose.')
  void streamPayments(
      String accountId,
      void Function(PaymentOperationResponse) onPayment,
      ) {
    paymentsStream(accountId).listen(onPayment);
  }
}
