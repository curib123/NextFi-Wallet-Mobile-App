// StellarWalletServices.dart
import 'dart:async';
import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/wallet_models.dart';
import 'package:next_fi/services/stellar/soroban_rpc.dart';
import 'package:next_fi/services/profit_address_vault_secure_storage.dart';

/// Production-ready Stellar service with:
/// - CreateAccount vs Payment for XLM sends (dest not yet funded)
/// - Hardened USDC sends (sender+dest trustline checks)
/// - Classic G… address normalization (rejects M… unless you add proper support)
/// - Clearer Horizon error messages on submit
/// - Read fallbacks (QuickNode) with headers; submit fallbacks kept simple
class StellarWalletServices {
  final String usdcIssuer;
  final StellarSDK sdk;

  // Optional Horizon alternatives (reads use headers; submits prefer public Horizon)
  final String? quickNodeUrlMainnet;
  final String? quickNodeUrlTestnet;
  final Map<String, String>? quickNodeDefaultHeaders;
  final StellarSDK? _sdkQuickNode;

  // Optional Soroban RPC (only used for fee/ledger watch; not for classic submits)
  final String? sorobanUrlMainnet;
  final String? sorobanUrlTestnet;
  final Map<String, String>? sorobanDefaultHeaders;
  final SorobanRpc? _soroban;

  final TransactionFeeVaultSecureStorage configVault;

  StellarWalletServices({
    required this.usdcIssuer,
    bool testnet = false,
    TransactionFeeVaultSecureStorage? configVault,
    this.quickNodeUrlMainnet,
    this.quickNodeUrlTestnet,
    this.quickNodeDefaultHeaders,
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
          return (url != null && url.isNotEmpty)
              ? SorobanRpc(url, sorobanDefaultHeaders)
              : null;
        })(),
        configVault = configVault ?? TransactionFeeVaultSecureStorage();

  bool get _isTestnet => identical(sdk, StellarSDK.TESTNET);
  Network get _network => _isTestnet ? Network.TESTNET : Network.PUBLIC;

  // ---------- Mnemonics ----------
  Future<String> _generateMnemonic({int wordCount = 12}) async {
    final wc = (wordCount == 24) ? 24 : 12;
    final strength = wc == 24 ? 256 : 128; // 24w -> 256b, 12w -> 128b
    final m = bip39.generateMnemonic(strength: strength);
    return m.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _validateMnemonic(String mnemonic) {
    final norm = mnemonic.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final wc = norm.isEmpty ? 0 : norm.split(' ').length;
    if (wc != 12 && wc != 24) return false;
    return bip39.validateMnemonic(norm);
  }

  // Public mnemonic API
  Future<String> generateMnemonic({int wordCount = 12}) =>
      _generateMnemonic(wordCount: wordCount);
  bool validateMnemonic(String mnemonic) => _validateMnemonic(mnemonic);
  Future<String> get mnemonic12 => _generateMnemonic(wordCount: 12);
  Future<String> get mnemonic24 => _generateMnemonic(wordCount: 24);

  // ---------- Assets ----------
  Asset get _xlm => Asset.NATIVE;
  Asset get _usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  static const double _kTxFeeUsdc = 0.005; // App fee “pegged” in USDC, converted to XLM
  static String _fmt7(num v) => v.toStringAsFixed(7);
  static Never _fail(String message, [Object? inner]) =>
      throw Exception(inner == null ? message : '$message (inner: $inner)');

  String get horizonBase =>
      _isTestnet ? 'https://horizon-testnet.stellar.org' : 'https://horizon.stellar.org';
  String? get _qnBase => _isTestnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;

  // ---------- HTTP with fallback (reads only) ----------
  Future<http.Response> _getWithFallback(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final primary = Uri.parse('$horizonBase$path').replace(queryParameters: query);
    try {
      final r = await http.get(primary).timeout(timeout);
      if (r.statusCode == 200) return r;
      if (r.statusCode == 429 || (r.statusCode >= 500 && r.statusCode <= 599)) {
        final fr = await _tryQuickNode(path, query: query, timeout: timeout);
        if (fr != null) return fr;
      }
      return r;
    } catch (_) {
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

  // ---------- Basics ----------
  Future<AccountResponse> _loadAccount(String accountId) =>
      sdk.accounts.account(accountId);

  bool get isTestnet => _isTestnet;
  Future<String> getTransactionFeeAddress() async =>
      (await configVault.readOrInit()).address;

  int _toStroops(double amount) => (amount * 1e7).round();
  double _fromStroops(int stroops) => stroops / 1e7;

  // Convert fixed USDC app-fee to XLM dynamically (with quotes -> fallback -> stored -> default)
  Future<double> _computeDynamicFeeXlm() async {
    try {
      final x1 = await quoteUsdcToXlm(_kTxFeeUsdc);
      if (x1 != null && x1 > 0) return x1;
    } catch (_) {}
    try {
      final usdcPer1Xlm = await quoteXlmToUsdc(1.0);
      if (usdcPer1Xlm != null && usdcPer1Xlm > 0) {
        final x2 = _kTxFeeUsdc / usdcPer1Xlm;
        if (x2 > 0) return x2;
      }
    } catch (_) {}
    try {
      return await configVault.getFeeXlm();
    } catch (_) {
      return 0.05; // safe default if all else fails
    }
  }

  Future<int> getCurrentFeeStroops() async {
    final xlm = await _computeDynamicFeeXlm();
    return (xlm * 1e7).ceil();
  }

  Future<double> getCurrentFeeXlm() async =>
      _fromStroops(await getCurrentFeeStroops());
  Future<String> getCurrentFeeLabel() async =>
      '${(await getCurrentFeeXlm()).toStringAsFixed(7)} XLM';

  // ---------- Helpers: account existence + address normalization ----------
  Future<bool> _accountExists(String accountId) async {
    try {
      await _loadAccount(accountId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures we use classic **G…** account ID (rejects muxed M… here).
  String _toClassicAccountId(String addr) {
    final a = addr.trim();
    if (a.startsWith('G') && a.length >= 56) {
      // Basic sanity validation via StrKey is internal to SDK; this is sufficient for flow guard.
      return a;
    }
    if (a.startsWith('M')) {
      _fail('Muxed (M…) addresses are not supported here. Use classic G… + memo.');
    }
    _fail('Invalid account id: $a');
  }

  // ---------- Balances ----------
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
        if (b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer) {
          return double.parse(b.balance);
        }
      }
      return 0.0;
    } catch (e) {
      _fail('Failed to fetch USDC balance', e);
    }
  }

  // ---------- Trustlines ----------
  Future<bool> hasUsdcTrustline(String accountId) async {
    final acc = await _loadAccount(accountId);
    return acc.balances
        .any((b) => b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer);
  }

  Future<String> createUsdcTrustline({
    required KeyPair keyPair,
    String limit = '922337203685.4775807',
  }) async {
    try {
      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(_usdc, limit).build())
          .setMaxOperationFee(100) // base safe per-op
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'ChangeTrust(USDC) failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create USDC trustline', e);
    }
  }

  Future<void> _ensureUsdcTrustlineSelf(
      KeyPair keyPair, {
        String limit = '922337203685.4775807',
      }) async {
    if (await hasUsdcTrustline(keyPair.accountId)) return;
    await createUsdcTrustline(keyPair: keyPair, limit: limit);
  }

  // ---------- Payments (app fee paid in XLM) ----------
  Future<List<String>> sendXlmWithFee({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');

    final dest = _toClassicAccountId(destination);
    final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

    // App fee
    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);
    final totalStroops = _toStroops(amount);
    if (totalStroops <= feeStroops) {
      _fail('Amount too small: must be greater than transaction fee of ${_fmt7(feeXlm)} XLM');
    }
    final recvXlm = _fromStroops(totalStroops - feeStroops);

    final acc = await _loadAccount(keyPair.accountId);

    // Estimate network fee per op
    final needsFeeOp = feeStroops > 0;
    final opCount = needsFeeOp ? 2 : 1;
    final feeXlmNet =
    await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

    final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

    final destExists = await _accountExists(dest);
    if (destExists) {
      tb.addOperation(
        PaymentOperationBuilder(dest, _xlm, _fmt7(recvXlm)).build(),
      );
    } else {
      // Create (fund) new account with recv amount
      tb.addOperation(
        CreateAccountOperationBuilder(dest, _fmt7(recvXlm)).build(),
      );
    }

    if (needsFeeOp) {
      tb.addOperation(
        PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
      );
    }
    if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

    final tx = tb.build();
    tx.sign(keyPair, _network);

    // Submit via public Horizon; optional fallback via alt Horizon (no custom headers)
    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'XLM send failed');
      return [res.hash!];
    } catch (_) {
      if (_sdkQuickNode != null) {
        final res = await _sdkQuickNode!.submitTransaction(tx);
        if (!res.success) _failSubmit(res, prefix: 'XLM send failed (fallback)');
        return [res.hash!];
      }
      rethrow;
    }
  }

  Future<List<String>> sendUsdcWithFee({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
  }) async {
    if (usdcAmount <= 0) _fail('usdcAmount must be > 0');

    final dest = _toClassicAccountId(destination);
    final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

    // Destination MUST exist and have USDC trustline
    if (!await _accountExists(dest)) {
      _fail('Destination account does not exist. Ask recipient to create/fund a Stellar account first.');
    }
    await _ensureUsdcTrustlineSelf(keyPair); // sender trustline
    if (!await hasUsdcTrustline(dest)) {
      _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
    }

    // App fee in XLM
    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);

    // Ensure sender has enough XLM to pay your app fee
    final senderXlmBal = await getXlmBalance(keyPair.accountId);
    if (senderXlmBal + 1e-7 < feeXlm) {
      _fail(
        'Insufficient XLM to pay the transaction fee of ${_fmt7(feeXlm)} XLM.',
      );
    }

    final acc = await _loadAccount(keyPair.accountId);

    final needsFeeOp = feeStroops > 0;
    final opCount = needsFeeOp ? 2 : 1;
    final feeXlmNet =
    await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

    final tb = TransactionBuilder(acc)
      ..setMaxOperationFee(perOpStroops)
      ..addOperation(
        PaymentOperationBuilder(dest, _usdc, _fmt7(usdcAmount)).build(),
      );

    if (needsFeeOp) {
      tb.addOperation(
        PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
      );
    }
    if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

    final tx = tb.build();
    tx.sign(keyPair, _network);

    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'USDC payment failed');
      return [res.hash!];
    } catch (_) {
      if (_sdkQuickNode != null) {
        final res = await _sdkQuickNode!.submitTransaction(tx);
        if (!res.success) _failSubmit(res, prefix: 'USDC payment failed (fallback)');
        return [res.hash!];
      }
      rethrow;
    }
  }

  // ---------- Swaps (Strict-Send) ----------
  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
  }) async {
    if (sendAmountXlm <= 0) _fail('sendAmountXlm must be > 0');
    if (minUsdcOut <= 0) _fail('minUsdcOut must be > 0');

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? _toClassicAccountId(destination!.trim())
          : self;

      if (!await _accountExists(dest)) {
        _fail('Destination account does not exist. Ask recipient to create/fund a Stellar account first.');
      }
      if (!await hasUsdcTrustline(dest)) {
        _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
      }

      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      final senderXlmBal = await getXlmBalance(self);
      if (senderXlmBal + 1e-7 < (sendAmountXlm + feeXlm)) {
        _fail(
          'Insufficient XLM to swap ${_fmt7(sendAmountXlm)} and pay ${_fmt7(feeXlm)} transaction fee.',
        );
      }

      final acc = await _loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
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

      if (needsFeeOp) {
        tb.addOperation(
          PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
        );
      }
      if (memoText?.isNotEmpty == true) tb.addMemo(Memo.text(memoText!));

      final tx = tb.build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'PathPaymentStrictSend XLM→USDC failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to swap XLM→USDC', e);
    }
  }

  Future<String> swapUsdcToXlm({
    required KeyPair keyPair,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
  }) async {
    if (sendAmountUsdc <= 0) _fail('sendAmountUsdc must be > 0');
    if (minXlmOut <= 0) _fail('minXlmOut must be > 0');

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? _toClassicAccountId(destination!.trim())
          : self;

      await _ensureUsdcTrustlineSelf(keyPair);

      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      final acc = await _loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet =
      await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        // Self swap (receive XLM then pay app fee from received XLM)
        if (minXlmOut + 1e-7 < feeXlm) {
          _fail(
            'minXlmOut too small to cover transaction fee of ${_fmt7(feeXlm)} XLM.',
          );
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
        // External dest: ensure sender already has fee XLM
        final senderXlmBal = await getXlmBalance(self);
        if (senderXlmBal + 1e-7 < feeXlm) {
          _fail(
            'Insufficient XLM to pay transaction fee of ${_fmt7(feeXlm)} XLM for external swap.',
          );
        }
        if (!await _accountExists(dest)) {
          _fail('Destination account does not exist. Ask recipient to create/fund a Stellar account first.');
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
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) {
        _failSubmit(res, prefix: 'PathPaymentStrictSend USDC→XLM failed');
      }
      return res.hash!;
    } catch (e) {
      _fail('Failed to swap USDC→XLM', e);
    }
  }

  // ---------- Quotes ----------
  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) async {
    String _destAssetToQuery(Asset a) {
      if (a is AssetTypeNative) return 'native';
      if (a is AssetTypeCreditAlphaNum) return '${a.code}:${a.issuerId}';
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
      final resp = await _getWithFallback(
        '/paths/strict-send',
        query: qp,
        timeout: const Duration(seconds: 20),
      );
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

  Future<double?> quoteXlmToUsdc(double sendAmountXlm) =>
      quoteStrictSend(
        sourceAsset: _xlm,
        sourceAmount: _fmt7(sendAmountXlm),
        destinationAssets: [_usdc],
      );

  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) =>
      quoteStrictSend(
        sourceAsset: _usdc,
        sourceAmount: _fmt7(sendAmountUsdc),
        destinationAssets: [_xlm],
      );

  Future<double> estimateNetworkFeeXlm({int opCount = 1, int percentile = 90}) async {
    final ops = opCount <= 0 ? 1 : opCount;
    try {
      final resp =
      await _getWithFallback('/fee_stats', timeout: const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;

        final base =
            int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
        final fc = (data['fee_charged'] as Map?) ?? const {};
        final p = percentile.clamp(10, 99);
        final perTxStroops =
            int.tryParse('${fc['p$p'] ?? fc['p50'] ?? base}') ?? base;

        var perOpStroops = (perTxStroops / ops).ceil();
        final maxReasonable = base * 50;
        if (perOpStroops < base) perOpStroops = base;
        if (perOpStroops > maxReasonable) perOpStroops = maxReasonable;

        final totalStroops = perOpStroops * ops;
        return totalStroops * 1e-7;
      }
    } catch (_) {}
    // Fallback: 200 stroops/op
    return (200 * (opCount <= 0 ? 1 : opCount)) * 1e-7;
  }

  // ---------- Streams ----------
  Stream<T> _sseWithFallback<T>(Stream<T> Function(StellarSDK s) build) {
    final controller = StreamController<T>();
    StreamSubscription<T>? sub;
    bool usingQuickNode = false;

    Future<void> _start(StellarSDK s) async {
      sub = build(s).listen(
        controller.add,
        onError: (e, st) async {
          if (!usingQuickNode && _sdkQuickNode != null) {
            usingQuickNode = true;
            try {
              await sub?.cancel();
            } catch (_) {}
            await _start(_sdkQuickNode!);
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
          .where((resp) =>
      resp is PaymentOperationResponse && resp.transactionSuccessful)
          .cast<PaymentOperationResponse>();
    }

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
          if (b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer) {
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
    int? lastSorobanLedger;

    Future<void> push(DateTime at) async {
      try {
        final x = await estimateNetworkFeeXlm(opCount: opCount, percentile: percentile);

        int base = 100;
        try {
          final resp =
          await _getWithFallback('/fee_stats', timeout: const Duration(seconds: 6));
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

    Stream<void> _ledgerStream(StellarSDK s) =>
        s.ledgers.cursor("now").stream().map((_) => null);

    final ledSub =
    _sseWithFallback<void>(_ledgerStream).listen((_) => push(DateTime.now()),
        onError: controller.addError, onDone: controller.close);

    Timer? sorobanTicker;
    if (_soroban != null) {
      sorobanTicker = Timer.periodic(const Duration(seconds: 8), (_) async {
        try {
          final seq = await _soroban!.getLatestLedgerSequence();
          if (seq == null) return;
          if (lastSorobanLedger == null || seq > lastSorobanLedger!) {
            lastSorobanLedger = seq;
            await push(DateTime.now());
          }
        } catch (_) {}
      });
    }

    controller.onCancel = () async {
      sorobanTicker?.cancel();
      await ledSub.cancel();
    };
    return controller.stream;
  }

  // ---------- Trades / Prices ----------
  TradesRequestBuilder _tradesForPairOn(
      StellarSDK s, Asset base, Asset counter) {
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
        if (ba != null && ba > 0 && ca != null) price = ca / ba; // USDC per XLM
        price ??= double.tryParse('${t.price}');
        if (price != null && price > 0) {
          // PairPrice expects: usdcPerXlm, xlmPerUsdc
          return PairPrice(price, DateTime.now());
        }
        throw StateError('Invalid trade price');
      });
    }

    return _sseWithFallback<PairPrice>(_build);
  }

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      xlmUsdcPriceStream().map((p) => sendAmountXlm * p.usdcPerXlm);

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      xlmUsdcPriceStream().map((p) => sendAmountUsdc * p.xlmPerUsdc);

  // ---------- Error helpers ----------
  Never _failSubmit(
      SubmitTransactionResponse res, {
        String prefix = 'Transaction failed',
      }) {
    final code = res.extras?.resultCodes?.transactionResultCode ?? 'tx_failed';
    final ops = res.extras?.resultCodes?.operationsResultCodes?.join(', ');
    final hash = res.hash;
    final msg =
        '$prefix ($code${ops != null ? '; ops: $ops' : ''}${hash != null ? '; hash: $hash' : ''})';
    _fail(msg);
  }
}
