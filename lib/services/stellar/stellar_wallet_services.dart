// StellarWalletServices.dart
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/wallet_models.dart';
import 'package:next_fi/services/stellar/soroban_rpc.dart';

// Import all sub-services
import 'package:next_fi/services/stellar/stellar_base_service.dart';
import 'package:next_fi/services/stellar/stellar_wallet_manager.dart';
import 'package:next_fi/services/stellar/stellar_account_service.dart';
import 'package:next_fi/services/stellar/stellar_payment_service.dart';
import 'package:next_fi/services/stellar/stellar_swap_service.dart';
import 'package:next_fi/services/stellar/stellar_claimable_balance_service.dart';
import 'package:next_fi/services/stellar/stellar_dex_service.dart';
import 'package:next_fi/services/stellar/stellar_fee_service.dart';
import 'package:next_fi/services/stellar/stellar_stream_service.dart';

export 'package:next_fi/services/stellar/stellar_base_service.dart'
    show StellarWalletError, ProgressCallback;

/// Production-ready Stellar wallet service built on `stellar_flutter_sdk` **v3**.
///
/// **Facade Pattern** - This class provides backwards compatibility by delegating
/// to specialized sub-services organized by feature:
///
/// - [StellarWalletManager]: Mnemonic generation, validation, key derivation
/// - [StellarAccountService]: Balances, trustlines, account management
/// - [StellarPaymentService]: XLM and USDC payments
/// - [StellarSwapService]: Path payments (swaps)
/// - [StellarClaimableBalanceService]: Time-locked and conditional payments
/// - [StellarDexService]: DEX trading, offers, order books
/// - [StellarFeeService]: Fee estimation and price quotes
/// - [StellarStreamService]: Real-time streams for payments, balances, prices
///
/// **v3 changes applied:**
/// - Mnemonic / HD-wallet helpers now use the SDK's built-in [Wallet] class (SEP-0005)
/// - `ManageData` value encoding fixed (String → Uint8List via UTF-8)
/// - BigInt used where the v3 migration guide requires it (e.g. `Memo.id`)
class StellarWalletServices {
  // Sub-services
  final StellarWalletManager walletManager;
  final StellarAccountService accountService;
  final StellarPaymentService paymentService;
  final StellarSwapService swapService;
  final StellarClaimableBalanceService claimableBalanceService;
  final StellarDexService dexService;
  final StellarFeeService feeService;
  final StellarStreamService streamService;

  // Legacy properties for backwards compatibility
  final String usdcIssuer;
  final StellarSDK sdk;
  final TransactionFeeVaultSecureStorage configVault;

  StellarWalletServices({
    required this.usdcIssuer,
    bool testnet = false,
    TransactionFeeVaultSecureStorage? configVault,
    FlutterSecureStorage? secureStorage,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
    String? sorobanUrlMainnet,
    String? sorobanUrlTestnet,
    Map<String, String>? sorobanDefaultHeaders,
  })  : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
        configVault = configVault ?? TransactionFeeVaultSecureStorage(),
        walletManager = StellarWalletManager(
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          secureStorage: secureStorage,
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        accountService = StellarAccountService(
          usdcIssuer: usdcIssuer,
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        feeService = StellarFeeService(
          usdcIssuer: usdcIssuer,
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          configVault: configVault,
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        paymentService = StellarPaymentService(
          accountService: StellarAccountService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          feeService: StellarFeeService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            configVault: configVault,
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        swapService = StellarSwapService(
          accountService: StellarAccountService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          feeService: StellarFeeService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            configVault: configVault,
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        claimableBalanceService = StellarClaimableBalanceService(
          accountService: StellarAccountService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        dexService = StellarDexService(
          accountService: StellarAccountService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        ),
        streamService = StellarStreamService(
          usdcIssuer: usdcIssuer,
          feeService: StellarFeeService(
            usdcIssuer: usdcIssuer,
            sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
            sdkQuickNode: _createQuickNodeSdk(
                testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
            configVault: configVault,
            quickNodeUrlMainnet: quickNodeUrlMainnet,
            quickNodeUrlTestnet: quickNodeUrlTestnet,
            quickNodeDefaultHeaders: quickNodeDefaultHeaders,
          ),
          sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
          sdkQuickNode: _createQuickNodeSdk(
              testnet, quickNodeUrlMainnet, quickNodeUrlTestnet),
          soroban: _createSorobanRpc(
              testnet, sorobanUrlMainnet, sorobanUrlTestnet, sorobanDefaultHeaders),
          quickNodeUrlMainnet: quickNodeUrlMainnet,
          quickNodeUrlTestnet: quickNodeUrlTestnet,
          quickNodeDefaultHeaders: quickNodeDefaultHeaders,
        );

  static StellarSDK? _createQuickNodeSdk(
      bool testnet, String? mainnetUrl, String? testnetUrl) {
    final url = testnet ? testnetUrl : mainnetUrl;
    return (url != null && url.isNotEmpty) ? StellarSDK(url) : null;
  }

  static SorobanRpc? _createSorobanRpc(bool testnet, String? mainnetUrl,
      String? testnetUrl, Map<String, String>? headers) {
    final url = testnet ? testnetUrl : mainnetUrl;
    return (url != null && url.isNotEmpty) ? SorobanRpc(url, headers) : null;
  }

  bool get isTestnet => sdk == StellarSDK.TESTNET;

  // ══════════════════════════════════════════════════════════════════════════
  // MNEMONIC & WALLET MANAGEMENT - Delegated to StellarWalletManager
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> generateMnemonic12() => walletManager.generateMnemonic12();
  Future<String> generateMnemonic24() => walletManager.generateMnemonic24();
  Future<String> generateMnemonic({int wordCount = 12}) =>
      walletManager.generateMnemonic(wordCount: wordCount);
  Future<bool> validateMnemonic(String mnemonic) =>
      walletManager.validateMnemonic(mnemonic);
  Future<Wallet> createWallet(String mnemonic, {String passphrase = ''}) =>
      walletManager.createWallet(mnemonic, passphrase: passphrase);
  Future<KeyPair> getKeyPairFromMnemonic(String mnemonic,
      {int index = 0, String passphrase = ''}) =>
      walletManager.getKeyPairFromMnemonic(mnemonic,
          index: index, passphrase: passphrase);
  Future<String> getAccountIdFromMnemonic(String mnemonic,
      {int index = 0, String passphrase = ''}) =>
      walletManager.getAccountIdFromMnemonic(mnemonic,
          index: index, passphrase: passphrase);
  Future<List<KeyPair>> deriveAccounts(String mnemonic,
      {required int count, String passphrase = ''}) =>
      walletManager.deriveAccounts(mnemonic,
          count: count, passphrase: passphrase);

  Future<void> storeMnemonic(String mnemonic, {String key = 'stellar_mnemonic'}) =>
      walletManager.storeMnemonic(mnemonic, key: key);
  Future<String?> retrieveMnemonic({String key = 'stellar_mnemonic'}) =>
      walletManager.retrieveMnemonic(key: key);
  Future<void> deleteMnemonic({String key = 'stellar_mnemonic'}) =>
      walletManager.deleteMnemonic(key: key);
  Future<void> storeSecretSeed(String secretSeed, {String key = 'stellar_secret'}) =>
      walletManager.storeSecretSeed(secretSeed, key: key);
  Future<String?> retrieveSecretSeed({String key = 'stellar_secret'}) =>
      walletManager.retrieveSecretSeed(key: key);
  Future<KeyPair?> getKeyPairFromStorage({String key = 'stellar_secret'}) =>
      walletManager.getKeyPairFromStorage(key: key);

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCES & TRUSTLINES - Delegated to StellarAccountService
  // ══════════════════════════════════════════════════════════════════════════

  Future<double> getXlmBalance(String accountId) =>
      accountService.getXlmBalance(accountId);
  Future<double> getUsdcBalance(String accountId) =>
      accountService.getUsdcBalance(accountId);
  Future<double> getAssetBalance(String accountId, Asset asset) =>
      accountService.getAssetBalance(accountId, asset);
  Future<List<Balance>> getAllBalances(String accountId) =>
      accountService.getAllBalances(accountId);

  Future<bool> hasUsdcTrustline(String accountId) =>
      accountService.hasUsdcTrustline(accountId);
  Future<bool> hasTrustline(String accountId, Asset asset) =>
      accountService.hasTrustline(accountId, asset);
  Future<String> createUsdcTrustline(
      {required KeyPair keyPair, String limit = '922337203685.4775807'}) =>
      accountService.createUsdcTrustline(keyPair: keyPair, limit: limit);
  Future<String> createTrustline(
      {required KeyPair keyPair,
        required Asset asset,
        String limit = '922337203685.4775807'}) =>
      accountService.createTrustline(keyPair: keyPair, asset: asset, limit: limit);
  Future<String> removeTrustline({required KeyPair keyPair, required Asset asset}) =>
      accountService.removeTrustline(keyPair: keyPair, asset: asset);

  // Account Data
  Future<String> setAccountData(
      {required KeyPair keyPair, required String key, required String value}) =>
      accountService.setAccountData(keyPair: keyPair, key: key, value: value);
  Future<String> deleteAccountData({required KeyPair keyPair, required String key}) =>
      accountService.deleteAccountData(keyPair: keyPair, key: key);
  Future<String?> getAccountData({required String accountId, required String key}) =>
      accountService.getAccountData(accountId: accountId, key: key);

  // Account Options
  Future<String> setAccountOptions({
    required KeyPair keyPair,
    String? homeDomain,
    String? inflationDestination,
    int? lowThreshold,
    int? mediumThreshold,
    int? highThreshold,
    int? masterWeight,
    int? setFlags,
    int? clearFlags,
  }) =>
      accountService.setAccountOptions(
        keyPair: keyPair,
        homeDomain: homeDomain,
        inflationDestination: inflationDestination,
        lowThreshold: lowThreshold,
        mediumThreshold: mediumThreshold,
        highThreshold: highThreshold,
        masterWeight: masterWeight,
        setFlags: setFlags,
        clearFlags: clearFlags,
      );

  Future<String> setHomeDomain({required KeyPair keyPair, required String domain}) =>
      accountService.setHomeDomain(keyPair: keyPair, domain: domain);

  Future<String> mergeAccount(
      {required KeyPair keyPair,
        required String destinationId,
        ProgressCallback? onProgress}) =>
      accountService.mergeAccount(
          keyPair: keyPair, destinationId: destinationId, onProgress: onProgress);

  Future<String> sponsorAccount({
    required KeyPair sponsorKeyPair,
    required String sponsoredId,
    required List<Operation> sponsoredOperations,
  }) =>
      accountService.sponsorAccount(
        sponsorKeyPair: sponsorKeyPair,
        sponsoredId: sponsoredId,
        sponsoredOperations: sponsoredOperations,
      );

  // Add these methods to your StellarWalletServices class
// Insert them in the "BALANCES & TRUSTLINES" section after getAssetBalance

  /// Get the base reserve amount (2 * baseReserve)
  /// This is the minimum balance required for an account with no subentries
  Future<double> getBaseReserve(String accountId) =>
      accountService.getBaseReserve(accountId);

  /// Get the trustline reserve amount (number of trustlines * subentryReserve)
  /// This is the reserve locked up by trustlines only
  Future<double> getTrustlineReserve(String accountId) =>
      accountService.getTrustlineReserve(accountId);

  /// Get the total subentry reserve (all subentries * subentryReserve)
  /// Includes trustlines, signers, data entries, and offers
  Future<double> getSubentryReserve(String accountId) =>
      accountService.getSubentryReserve(accountId);

  /// Get detailed reserve breakdown
  /// Returns map with base, trustline, and other subentry reserves
  Future<Map<String, double>> getReserveBreakdown(String accountId) =>
      accountService.getReserveBreakdown(accountId);

  /// Get XLM minimum balance (base reserve + subentry reserves)
  Future<double> getXlmMinimumBalance(String accountId) =>
      accountService.getXlmMinimumBalance(accountId);

  /// Get total XLM balance (includes reserves - use for display purposes only)
  Future<double> getTotalXlmBalance(String accountId) =>
      accountService.getTotalXlmBalance(accountId);

  /// Get detailed balance breakdown for an account
  /// Returns map with total, spendable, reserved, and locked amounts
  Future<Map<String, double>> getXlmBalanceBreakdown(String accountId) =>
      accountService.getXlmBalanceBreakdown(accountId);

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENTS - Delegated to StellarPaymentService
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<String>> sendXlmWithFee({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) =>
      paymentService.sendXlmWithFee(
        keyPair: keyPair,
        destination: destination,
        amount: amount,
        memoText: memoText,
        onProgress: onProgress,
      );

  Future<List<String>> sendUsdcWithFee({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) =>
      paymentService.sendUsdcWithFee(
        keyPair: keyPair,
        destination: destination,
        usdcAmount: usdcAmount,
        memoText: memoText,
        onProgress: onProgress,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // SWAPS - Delegated to StellarSwapService
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) =>
      swapService.swapXlmToUsdc(
        keyPair: keyPair,
        sendAmountXlm: sendAmountXlm,
        minUsdcOut: minUsdcOut,
        destination: destination,
        memoText: memoText,
        onProgress: onProgress,
      );

  Future<String> swapUsdcToXlm({
    required KeyPair keyPair,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) =>
      swapService.swapUsdcToXlm(
        keyPair: keyPair,
        sendAmountUsdc: sendAmountUsdc,
        minXlmOut: minXlmOut,
        destination: destination,
        memoText: memoText,
        onProgress: onProgress,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // CLAIMABLE BALANCES - Delegated to StellarClaimableBalanceService
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required List<Claimant> claimants,
    String? memoText,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.createClaimableBalance(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        claimants: claimants,
        memoText: memoText,
        onProgress: onProgress,
      );

  Future<String> createUnconditionalClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.createUnconditionalClaimableBalance(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        onProgress: onProgress,
      );

  Future<String> createTimeLockedPayment({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.createTimeLockedPayment(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        unlockTime: unlockTime,
        onProgress: onProgress,
      );

  Future<String> createUnconditionalWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.createUnconditionalWithExpiry(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        expiryTime: expiryTime,
        onProgress: onProgress,
      );

  Future<String> createTimeLockedWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.createTimeLockedWithExpiry(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        unlockTime: unlockTime,
        expiryTime: expiryTime,
        onProgress: onProgress,
      );

  Future<String> claimClaimableBalance({
    required KeyPair keyPair,
    required String balanceId,
    ProgressCallback? onProgress,
  }) =>
      claimableBalanceService.claimClaimableBalance(
        keyPair: keyPair,
        balanceId: balanceId,
        onProgress: onProgress,
      );

  Future<List<ClaimableBalanceResponse>> getClaimableBalances({
    required String accountId,
    int limit = 200,
  }) =>
      claimableBalanceService.getClaimableBalances(
          accountId: accountId, limit: limit);

  Future<List<ClaimableBalanceResponse>> getSentClaimableBalances({
    required String accountId,
    int limit = 200,
  }) =>
      claimableBalanceService.getSentClaimableBalances(
          accountId: accountId, limit: limit);

  Future<Map<String, List<ClaimableBalanceResponse>>> getAllClaimableBalances({
    required String accountId,
    int limit = 200,
  }) =>
      claimableBalanceService.getAllClaimableBalances(
          accountId: accountId, limit: limit);

  Future<ClaimableBalanceResponse?> getClaimableBalanceById({
    required String balanceId,
  }) =>
      claimableBalanceService.getClaimableBalanceById(balanceId: balanceId);

  Future<bool> canClaimBalance({
    required String accountId,
    required String balanceId,
  }) =>
      claimableBalanceService.canClaimBalance(
          accountId: accountId, balanceId: balanceId);

  // ══════════════════════════════════════════════════════════════════════════
  // DEX TRADING - Delegated to StellarDexService
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createSellOffer({
    required KeyPair keyPair,
    required Asset selling,
    required Asset buying,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) =>
      dexService.createSellOffer(
        keyPair: keyPair,
        selling: selling,
        buying: buying,
        amount: amount,
        price: price,
        offerId: offerId,
        onProgress: onProgress,
      );

  Future<String> createBuyOffer({
    required KeyPair keyPair,
    required Asset buying,
    required Asset selling,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) =>
      dexService.createBuyOffer(
        keyPair: keyPair,
        buying: buying,
        selling: selling,
        amount: amount,
        price: price,
        offerId: offerId,
        onProgress: onProgress,
      );

  Future<String> cancelOffer({
    required KeyPair keyPair,
    required int offerId,
    required Asset selling,
    required Asset buying,
    ProgressCallback? onProgress,
  }) =>
      dexService.cancelOffer(
        keyPair: keyPair,
        offerId: offerId,
        selling: selling,
        buying: buying,
        onProgress: onProgress,
      );

  Future<List<OfferResponse>> getAccountOffers({
    required String accountId,
    int limit = 200,
  }) =>
      dexService.getAccountOffers(accountId: accountId, limit: limit);

  Future<OrderBookResponse> getOrderBook({
    required Asset selling,
    required Asset buying,
    int limit = 20,
  }) =>
      dexService.getOrderBook(selling: selling, buying: buying, limit: limit);

  // ══════════════════════════════════════════════════════════════════════════
  // FEE & QUOTES - Delegated to StellarFeeService
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> getTransactionFeeAddress() => feeService.getTransactionFeeAddress();
  Future<int> getCurrentFeeStroops() => feeService.getCurrentFeeStroops();
  Future<double> getCurrentFeeXlm() => feeService.getCurrentFeeXlm();
  Future<String> getCurrentFeeLabel() => feeService.getCurrentFeeLabel();

  Future<double> estimateNetworkFeeXlm({int opCount = 1, int percentile = 90}) =>
      feeService.estimateNetworkFeeXlm(opCount: opCount, percentile: percentile);

  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) =>
      feeService.quoteStrictSend(
        sourceAsset: sourceAsset,
        sourceAmount: sourceAmount,
        destinationAssets: destinationAssets,
      );

  Future<double?> quoteXlmToUsdc(double sendAmountXlm) =>
      feeService.quoteXlmToUsdc(sendAmountXlm);
  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) =>
      feeService.quoteUsdcToXlm(sendAmountUsdc);

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMS - Delegated to StellarStreamService
  // ══════════════════════════════════════════════════════════════════════════

  Stream<PaymentOperationResponse> paymentsStream(String accountId) =>
      streamService.paymentsStream(accountId);

  Stream<AccountState> accountStateStream(String accountId) =>
      streamService.accountStateStream(accountId);

  Stream<FeeEstimate> feeEstimateStream({int opCount = 1, int percentile = 90}) =>
      streamService.feeEstimateStream(opCount: opCount, percentile: percentile);

  Stream<PairPrice> xlmUsdcPriceStream() => streamService.xlmUsdcPriceStream();

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      streamService.quoteXlmToUsdcStream(sendAmountXlm);

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      streamService.quoteUsdcToXlmStream(sendAmountUsdc);
}