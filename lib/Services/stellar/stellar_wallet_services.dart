import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:next_fi/Services/profit_address_vault_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';


class StellarWalletService {
  /// Horizon SDK instance (PUBLIC or TESTNET).
  final StellarSDK sdk;

  /// Immutable profit-address vault (source of truth is a compiled constant).
  final ProfitAddressVaultSecureStorage profitVault;

  /// Default USDC issuer on Stellar Mainnet (configurable).
  /// You may override in the constructor if needed.
  // Official issuers
  static const String _DEFAULT_USDC_ISSUER_MAINNET =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';

  static const String _DEFAULT_USDC_ISSUER_TESTNET =
      'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

  /// Optional override for USDC issuer (mainnet / testnet).
  final String? usdcIssuerOverrideMainnet;
  final String? usdcIssuerOverrideTestnet;

  StellarWalletService({
    bool testnet = false,
    this.usdcIssuerOverrideMainnet,
    this.usdcIssuerOverrideTestnet,
    ProfitAddressVaultSecureStorage? profitVault,
  })  : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
        profitVault = profitVault ?? const ProfitAddressVaultSecureStorage();

  // ---------- Internals ----------
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

  Future<AccountResponse> _loadAccount(String accountId) =>
      sdk.accounts.account(accountId);

  // ---------- PUBLIC helpers (exposed for UI) ----------
  bool get isTestnet => _isTestnet;

  /// Horizon base used by this SDK instance.
  String get horizonBase =>
      _isTestnet ? 'https://horizon-testnet.stellar.org' : 'https://horizon.stellar.org';

  String get usdcIssuer => _usdcIssuer;

  // ---------- Wallet Basics ----------
  static Future<String> generateMnemonic() => Wallet.generate24WordsMnemonic();

  static Future<Wallet> walletFromMnemonic(String mnemonic) => Wallet.from(mnemonic);

  static Future<KeyPair> getKeyPair(Wallet wallet, {int index = 0}) => wallet.getKeyPair(index: index);

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
        if (b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer) {
          return double.parse(b.balance);
        }
      }
      return 0.0;
    } catch (e) {
      _fail('Failed to fetch USDC balance', e);
    }
  }

  // ---------- Trustlines (USDC) ----------
  Future<bool> hasUsdcTrustline(String accountId) async {
    final acc = await _loadAccount(accountId);
    return acc.balances.any((b) => b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer);
  }

  /// Create/raise USDC trustline for the signer of [secretSeed].
  /// [limit] defaults to high decimal string.
  Future<String> createUsdcTrustline({
    required String secretSeed,
    String limit = '922337203685.4775807',
  }) async {
    try {
      final kp = KeyPair.fromSecretSeed(secretSeed);
      final acc = await _loadAccount(kp.accountId);

      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(_usdc, limit).build())
          .setMaxOperationFee(100) // 100 / op
          .build();

      tx.sign(kp, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('ChangeTrust(USDC) failed: ${res.resultXdr}');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create USDC trustline', e);
    }
  }

  /// Ensure the signer has USDC trustline (creates it if missing).
  Future<void> _ensureUsdcTrustlineSelf(String secretSeed, {String limit = '922337203685.4775807'}) async {
    final kp = KeyPair.fromSecretSeed(secretSeed);
    if (await hasUsdcTrustline(kp.accountId)) return;
    await createUsdcTrustline(secretSeed: secretSeed, limit: limit);
  }

  // Helpers for precise amounts
  int _toStroops(double amount) => (amount * 1e7).round();
  double _fromStroops(int stroops) => stroops / 1e7;

  /// Send XLM and collect a 1% fee to the **immutable profit address** (vault) atomically.
  /// Returns a single tx hash in the list (to preserve your original return type).
  Future<List<String>> sendXlmWithFee({
    required String secretSeed,
    required String destination,
    required double amount,
    String? memoText,
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');
    final dest = destination.trim();
    if (dest.isEmpty) _fail('Destination is required');

    // Always read the fee address from the secure, immutable vault (cannot be changed).
    final feeAddr = await profitVault.readOrInit();

    // Validate account IDs (throws on invalid G... address)
    KeyPair.fromAccountId(dest);
    KeyPair.fromAccountId(feeAddr);

    // Split in stroops to avoid float rounding bugs
    final total = _toStroops(amount);
    final feePart = (total / 100).round(); // 1%
    final recvPart = total - feePart;
    if (recvPart <= 0) _fail('Amount too small after 1% fee');

    final sender = KeyPair.fromSecretSeed(secretSeed);
    final acc = await _loadAccount(sender.accountId);

    // Estimate a sane per-op fee from /fee_stats; 2 ops (user payment + fee)
    final opCount = feePart > 0 ? 2 : 1;
    final feeXlm = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlm / 1e-7 / opCount).ceil(); // XLM -> stroops/op

    final tb = TransactionBuilder(acc)
      ..setMaxOperationFee(perOpStroops)
      ..addOperation(
        PaymentOperationBuilder(dest, _xlm, _fmt7(_fromStroops(recvPart))).build(),
      );

    if (feePart > 0) {
      tb.addOperation(
        PaymentOperationBuilder(feeAddr, _xlm, _fmt7(_fromStroops(feePart))).build(),
      );
    }

    if (memoText != null && memoText.isNotEmpty) {
      tb.addMemo(Memo.text(memoText));
    }

    final tx = tb.build();
    tx.sign(sender, _network);

    final res = await sdk.submitTransaction(tx);
    if (!res.success) _fail('XLM payment failed: ${res.resultXdr}');
    return [res.hash!]; // single atomic tx hash
  }

  // ---------- Swaps: XLM ↔ USDC (PathPaymentStrictSend) ----------
  /// Swap XLM → USDC (strict-send).
  /// If [destination] is omitted, swap to self and auto-create USDC trustline if missing.
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

      // Ensure destination has USDC trustline
      if (dest == kp.accountId) {
        await _ensureUsdcTrustlineSelf(secretSeed);
      } else {
        if (!await hasUsdcTrustline(dest)) {
          _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
        }
      }

      final acc = await _loadAccount(kp.accountId);

      final op = PathPaymentStrictSendOperationBuilder(
        _xlm,
        _fmt7(sendAmountXlm),
        dest,
        _usdc,
        _fmt7(minUsdcOut),
      ).build();

      final tb = TransactionBuilder(acc)
        ..addOperation(op)
        ..setMaxOperationFee(200);

      if (memoText != null && memoText.isNotEmpty) tb.addMemo(Memo.text(memoText));

      final tx = tb.build();
      tx.sign(kp, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('PathPaymentStrictSend XLM→USDC failed: ${res.resultXdr}');
      return res.hash!;
    } catch (e) {
      _fail('Failed to swap XLM→USDC', e);
    }
  }

  /// Swap USDC → XLM (strict-send).
  /// Source must have a USDC trustline (auto-created if missing).
  /// If [destination] is omitted, swap to self.
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

      // Ensure sender can spend USDC (create trustline if missing).
      await _ensureUsdcTrustlineSelf(secretSeed);

      // Optional: preflight balance check (helpful UX).
      final usdcBal = await getUsdcBalance(kp.accountId);
      if (sendAmountUsdc > usdcBal + 1e-7) {
        _fail('Insufficient USDC balance. Have ${_fmt7(usdcBal)}, need ${_fmt7(sendAmountUsdc)}.');
      }

      final dest = (destination?.trim().isNotEmpty == true) ? destination!.trim() : kp.accountId;

      final acc = await _loadAccount(kp.accountId);

      final op = PathPaymentStrictSendOperationBuilder(
        _usdc,
        _fmt7(sendAmountUsdc),
        dest,
        _xlm,
        _fmt7(minXlmOut),
      ).build();

      final tb = TransactionBuilder(acc)
        ..addOperation(op)
        ..setMaxOperationFee(200);

      if (memoText != null && memoText.isNotEmpty) tb.addMemo(Memo.text(memoText));

      final tx = tb.build();
      tx.sign(kp, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('PathPaymentStrictSend USDC→XLM failed: ${res.resultXdr}');
      return res.hash!;
    } catch (e) {
      _fail('Failed to swap USDC→XLM', e);
    }
  }

  // ---------- Quote helpers (strict-send path) ----------
  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) async {
    // For destination_assets param in strict-send:
    // Must be "native" or "CODE:ISSUER" (no credit_alphanum prefix)
    String _destAssetToQuery(Asset a) {
      if (a is AssetTypeNative) return 'native';
      if (a is AssetTypeCreditAlphaNum) {
        final code = a.code;       // e.g., "USDC"
        final issuer = a.issuerId; // G... issuer account
        return '$code:$issuer';
      }
      return 'native';
    }

    final destParam = destinationAssets.map(_destAssetToQuery).join(',');

    // Source asset still uses type/code/issuer fields
    final qp = <String, String>{
      'source_amount': sourceAmount,
      if (sourceAsset is AssetTypeNative) 'source_asset_type': 'native',
      if (sourceAsset is AssetTypeCreditAlphaNum) ...{
        'source_asset_type': 'credit_alphanum${sourceAsset.code.length}', // 4 or 12
        'source_asset_code': sourceAsset.code,
        'source_asset_issuer': sourceAsset.issuerId,
      },
      'destination_assets': destParam,
    };

    final uri = Uri.parse('$horizonBase/paths/strict-send').replace(queryParameters: qp);

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));
      // ignore: avoid_print
      print('[quoteStrictSend] GET $uri => ${resp.statusCode}');
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

  /// Convenience quotes:
  Future<double?> quoteXlmToUsdc(double sendAmountXlm) => quoteStrictSend(
    sourceAsset: _xlm,
    sourceAmount: _fmt7(sendAmountXlm),
    destinationAssets: [_usdc], // becomes "USDC:<issuer>"
  );

  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) => quoteStrictSend(
    sourceAsset: _usdc,
    sourceAmount: _fmt7(sendAmountUsdc),
    destinationAssets: [_xlm], // becomes "native"
  );

  Future<double> estimateNetworkFeeXlm({int opCount = 1, int percentile = 90}) async {
    final ops = opCount <= 0 ? 1 : opCount;
    try {
      final uri = Uri.parse('${this.horizonBase}/fee_stats');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;

        // Base fee (stroops/op)
        final base = int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;

        // Use actual fees paid, not max bids
        final fc = (data['fee_charged'] as Map?) ?? const {};
        final p = percentile.clamp(10, 99);
        final perTxStroops = int.tryParse('${fc['p$p'] ?? fc['p50'] ?? base}') ?? base;

        // Convert per-transaction -> per-operation (ceil), then clamp
        var perOpStroops = (perTxStroops / ops).ceil();
        // Clamp to [base, base * 50] per-op to ignore pathological outliers
        final maxReasonable = base * 50; // ~0.0005 XLM if base=100
        if (perOpStroops < base) perOpStroops = base;
        if (perOpStroops > maxReasonable) perOpStroops = maxReasonable;

        final totalStroops = perOpStroops * ops;
        return totalStroops * 1e-7; // stroops -> XLM
      }
    } catch (_) {
      // fall through to fallback
    }
    // Conservative fallback ~200 stroops/op
    return (200 * (opCount <= 0 ? 1 : opCount)) * 1e-7;
  }

  // ---------- Federation & Streaming ----------
  Future<FederationResponse> resolveFederationAddress(String stellarAddress) =>
      Federation.resolveStellarAddress(stellarAddress);

  void streamPayments(
      String accountId,
      void Function(PaymentOperationResponse) onPayment,
      ) {
    sdk.payments.forAccount(accountId).cursor("now").stream().listen((resp) {
      if (resp is PaymentOperationResponse && resp.transactionSuccessful) {
        onPayment(resp);
      }
    });
  }
}
