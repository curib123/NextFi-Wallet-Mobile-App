import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class StellarWalletService {
  /// Horizon SDK instance (PUBLIC or TESTNET).
  final StellarSDK sdk;

  /// Profit address for 1% fee used by [sendXlmWithFee].
   String profitAddress = '';

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
     this.profitAddress = '',
    bool testnet = false,
    this.usdcIssuerOverrideMainnet,
    this.usdcIssuerOverrideTestnet,
  }) : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC;

  // ---------- Internals ----------
  bool get _isTestnet => identical(sdk, StellarSDK.TESTNET);
  Network get _network => _isTestnet ? Network.TESTNET : Network.PUBLIC;

  Asset get _xlm => Asset.NATIVE;

  String get _usdcIssuer =>
      _isTestnet
          ? (usdcIssuerOverrideTestnet ?? _DEFAULT_USDC_ISSUER_TESTNET)
          : (usdcIssuerOverrideMainnet ?? _DEFAULT_USDC_ISSUER_MAINNET);

  Asset get _usdc => AssetTypeCreditAlphaNum4('USDC', _usdcIssuer);

  static String _fmt7(num v) => v.toStringAsFixed(7);

  static Never _fail(String message, [Object? inner]) {
    throw Exception(inner == null ? message : '$message (inner: $inner)');
  }

  Future<AccountResponse> _loadAccount(String accountId) =>
      sdk.accounts.account(accountId);

  // ---------- Wallet Basics ----------
  static Future<String> generateMnemonic() => Wallet.generate24WordsMnemonic();

  static Future<Wallet> walletFromMnemonic(String mnemonic) =>
      Wallet.from(mnemonic);

  static Future<KeyPair> getKeyPair(Wallet wallet, {int index = 0}) =>
      wallet.getKeyPair(index: index);

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
    return acc.balances.any(
          (b) => b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer,
    );
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
          .setMaxOperationFee(100) // 100  / op
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
  Future<void> _ensureUsdcTrustlineSelf(String secretSeed,
      {String limit = '922337203685.4775807'}) async {
    final kp = KeyPair.fromSecretSeed(secretSeed);
    if (await hasUsdcTrustline(kp.accountId)) return;
    await createUsdcTrustline(secretSeed: secretSeed, limit: limit);
  }

  // ---------- Send XLM with 1% profit fee ----------
  Future<List<String>> sendXlmWithFee({
    required String secretSeed,
    required String destination,
    required double amount,
    String? memoText,
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');
    if (destination.trim().isEmpty) _fail('Destination is required');

    final sender = KeyPair.fromSecretSeed(secretSeed);
    final recv = double.parse((amount * 0.99).toStringAsFixed(7));
    final fee = double.parse((amount * 0.01).toStringAsFixed(7));

    final tx1 = await _sendXlm(sender, destination.trim(), recv, memoText: memoText);
    final tx2 = await _sendXlm(sender, profitAddress, fee, memoText: 'Profit Fee');
    return [tx1, tx2];
  }

  Future<String> _sendXlm(
      KeyPair sender,
      String destination,
      double amount, {
        String? memoText,
      }) async {
    try {
      final acc = await _loadAccount(sender.accountId);

      final builder = TransactionBuilder(acc)
        ..addOperation(
          PaymentOperationBuilder(destination, _xlm, _fmt7(amount)).build(),
        )
        ..setMaxOperationFee(100);

      if (memoText != null && memoText.isNotEmpty) {
        builder.addMemo(Memo.text(memoText));
      }

      final tx = builder.build();
      tx.sign(sender, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _fail('XLM payment failed: ${res.resultXdr}');
      return res.hash!;
    } catch (e) {
      _fail('Failed to send XLM', e);
    }
  }

  // ---------- Swaps: XLM ↔ USDC (PathPaymentStrictSend) ----------
  // Notes:
  // - Destination must have USDC trustline when receiving USDC.
  // - For best prices across multi-hop routes, add a path discovery step
  //   (not required for basic direct XLM/USDC pools).

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
      final dest = (destination?.trim().isNotEmpty == true)
          ? destination!.trim()
          : kp.accountId;

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
        _fail('Insufficient USDC balance. Have $_fmt7(usdcBal), need $_fmt7(sendAmountUsdc).');
      }

      final dest = (destination?.trim().isNotEmpty == true)
          ? destination!.trim()
          : kp.accountId;

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
