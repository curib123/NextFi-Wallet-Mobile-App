// lib/services/stellar/stellar_wallet_services.dart
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/wallet_models.dart';
import 'package:next_fi/core/services/stellar/soroban_rpc.dart';

// Import all sub-services
import 'package:next_fi/core/services/stellar/stellar_base_service.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_manager.dart';
import 'package:next_fi/core/services/stellar/stellar_account_service.dart';
import 'package:next_fi/core/services/stellar/stellar_payment_service.dart';
import 'package:next_fi/core/services/stellar/stellar_swap_service.dart';
import 'package:next_fi/core/services/stellar/stellar_claimable_balance_service.dart';
import 'package:next_fi/core/services/stellar/stellar_dex_service.dart';
import 'package:next_fi/core/services/stellar/stellar_fee_service.dart';
import 'package:next_fi/core/services/stellar/stellar_stream_service.dart';

// Export base service types
export 'package:next_fi/core/services/stellar/stellar_base_service.dart'
    show StellarWalletError, ProgressCallback;

/// Production-ready Stellar wallet service with integrated activity logging.
///
/// **Facade Pattern** - Delegates to specialized sub-services organized by feature.
/// Now includes automatic activity logging and user notifications for all operations.
///
/// Features:
/// - Automatic activity logging for all blockchain operations
/// - Real-time toast notifications
/// - Progress tracking with user-friendly messages
/// - Error handling with actionable advice
/// - Transaction history and audit trail
class StellarWalletServices {
  static const double defaultReceiverActivationXlm =
      StellarAccountService.fallbackAccountActivationMinXlm;
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

  StellarWalletServices({
    required this.usdcIssuer,
    bool testnet = false,
    FlutterSecureStorage? secureStorage,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
    String? sorobanUrlMainnet,
    String? sorobanUrlTestnet,
    Map<String, String>? sorobanDefaultHeaders,
  }) : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
       walletManager = StellarWalletManager(
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         secureStorage: secureStorage,
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       accountService = StellarAccountService(
         usdcIssuer: usdcIssuer,
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       feeService = StellarFeeService(
         usdcIssuer: usdcIssuer,
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       paymentService = StellarPaymentService(
         accountService: StellarAccountService(
           usdcIssuer: usdcIssuer,
           sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
           sdkQuickNode: _createQuickNodeSdk(
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       swapService = StellarSwapService(
         accountService: StellarAccountService(
           usdcIssuer: usdcIssuer,
           sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
           sdkQuickNode: _createQuickNodeSdk(
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         feeService: StellarFeeService(
           usdcIssuer: usdcIssuer,
           sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
           sdkQuickNode: _createQuickNodeSdk(
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       claimableBalanceService = StellarClaimableBalanceService(
         accountService: StellarAccountService(
           usdcIssuer: usdcIssuer,
           sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
           sdkQuickNode: _createQuickNodeSdk(
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       ),
       dexService = StellarDexService(
         accountService: StellarAccountService(
           usdcIssuer: usdcIssuer,
           sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
           sdkQuickNode: _createQuickNodeSdk(
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
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
             testnet,
             quickNodeUrlMainnet,
             quickNodeUrlTestnet,
           ),
           quickNodeUrlMainnet: quickNodeUrlMainnet,
           quickNodeUrlTestnet: quickNodeUrlTestnet,
           quickNodeDefaultHeaders: quickNodeDefaultHeaders,
         ),
         sdk: testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
         sdkQuickNode: _createQuickNodeSdk(
           testnet,
           quickNodeUrlMainnet,
           quickNodeUrlTestnet,
         ),
         soroban: _createSorobanRpc(
           testnet,
           sorobanUrlMainnet,
           sorobanUrlTestnet,
           sorobanDefaultHeaders,
         ),
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       );

  static StellarSDK? _createQuickNodeSdk(
    bool testnet,
    String? mainnetUrl,
    String? testnetUrl,
  ) {
    final url = testnet ? testnetUrl : mainnetUrl;
    return (url != null && url.isNotEmpty) ? StellarSDK(url) : null;
  }

  static SorobanRpc? _createSorobanRpc(
    bool testnet,
    String? mainnetUrl,
    String? testnetUrl,
    Map<String, String>? headers,
  ) {
    final url = testnet ? testnetUrl : mainnetUrl;
    return (url != null && url.isNotEmpty) ? SorobanRpc(url, headers) : null;
  }

  bool get isTestnet => sdk == StellarSDK.TESTNET;

  // MNEMONIC & WALLET MANAGEMENT
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> generateMnemonic12() => walletManager.generateMnemonic12();
  Future<String> generateMnemonic24() => walletManager.generateMnemonic24();
  Future<String> generateMnemonic({int wordCount = 12}) =>
      walletManager.generateMnemonic(wordCount: wordCount);
  Future<bool> validateMnemonic(String mnemonic) =>
      walletManager.validateMnemonic(mnemonic);
  Future<Wallet> createWallet(String mnemonic, {String passphrase = ''}) =>
      walletManager.createWallet(mnemonic, passphrase: passphrase);
  Future<KeyPair> getKeyPairFromMnemonic(
    String mnemonic, {
    int index = 0,
    String passphrase = '',
  }) => walletManager.getKeyPairFromMnemonic(
    mnemonic,
    index: index,
    passphrase: passphrase,
  );
  Future<String> getAccountIdFromMnemonic(
    String mnemonic, {
    int index = 0,
    String passphrase = '',
  }) => walletManager.getAccountIdFromMnemonic(
    mnemonic,
    index: index,
    passphrase: passphrase,
  );
  Future<List<KeyPair>> deriveAccounts(
    String mnemonic, {
    required int count,
    String passphrase = '',
  }) => walletManager.deriveAccounts(
    mnemonic,
    count: count,
    passphrase: passphrase,
  );

  Future<void> storeMnemonic(
    String mnemonic, {
    String key = 'stellar_mnemonic',
  }) => walletManager.storeMnemonic(mnemonic, key: key);
  Future<String?> retrieveMnemonic({String key = 'stellar_mnemonic'}) =>
      walletManager.retrieveMnemonic(key: key);
  Future<void> deleteMnemonic({String key = 'stellar_mnemonic'}) =>
      walletManager.deleteMnemonic(key: key);
  Future<void> storeSecretSeed(
    String secretSeed, {
    String key = 'stellar_secret',
  }) => walletManager.storeSecretSeed(secretSeed, key: key);
  Future<String?> retrieveSecretSeed({String key = 'stellar_secret'}) =>
      walletManager.retrieveSecretSeed(key: key);
  Future<KeyPair?> getKeyPairFromStorage({String key = 'stellar_secret'}) =>
      walletManager.getKeyPairFromStorage(key: key);

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // BALANCES & TRUSTLINES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

  Future<String> createUsdcTrustline({
    required KeyPair keyPair,
    String limit = '922337203685.4775807',
  }) => accountService.createUsdcTrustline(keyPair: keyPair, limit: limit);

  Future<String> createTrustline({
    required KeyPair keyPair,
    required Asset asset,
    String limit = '922337203685.4775807',
  }) => accountService.createTrustline(
    keyPair: keyPair,
    asset: asset,
    limit: limit,
  );

  Future<String> removeTrustline({
    required KeyPair keyPair,
    required Asset asset,
  }) => accountService.removeTrustline(keyPair: keyPair, asset: asset);

  // Account Data
  Future<String> setAccountData({
    required KeyPair keyPair,
    required String key,
    required String value,
  }) => accountService.setAccountData(keyPair: keyPair, key: key, value: value);
  Future<String> deleteAccountData({
    required KeyPair keyPair,
    required String key,
  }) => accountService.deleteAccountData(keyPair: keyPair, key: key);
  Future<String?> getAccountData({
    required String accountId,
    required String key,
  }) => accountService.getAccountData(accountId: accountId, key: key);

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
  }) => accountService.setAccountOptions(
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

  Future<String> setHomeDomain({
    required KeyPair keyPair,
    required String domain,
  }) => accountService.setHomeDomain(keyPair: keyPair, domain: domain);

  Future<String> mergeAccount({
    required KeyPair keyPair,
    required String destinationId,
    ProgressCallback? onProgress,
  }) => accountService.mergeAccount(
    keyPair: keyPair,
    destinationId: destinationId,
    onProgress: onProgress,
  );

  Future<String> sponsorAccount({
    required KeyPair sponsorKeyPair,
    required String sponsoredId,
    required List<Operation> sponsoredOperations,
  }) => accountService.sponsorAccount(
    sponsorKeyPair: sponsorKeyPair,
    sponsoredId: sponsoredId,
    sponsoredOperations: sponsoredOperations,
  );

  Future<double> getBaseReserve(String accountId) =>
      accountService.getBaseReserve(accountId);
  Future<double> getTrustlineReserve(String accountId) =>
      accountService.getTrustlineReserve(accountId);
  Future<double> getSubentryReserve(String accountId) =>
      accountService.getSubentryReserve(accountId);
  Future<Map<String, double>> getReserveBreakdown(String accountId) =>
      accountService.getReserveBreakdown(accountId);
  Future<double> getXlmMinimumBalance(String accountId) =>
      accountService.getXlmMinimumBalance(accountId);
  Future<double> getTotalXlmBalance(String accountId) =>
      accountService.getTotalXlmBalance(accountId);
  Future<Map<String, double>> getXlmBalanceBreakdown(String accountId) =>
      accountService.getXlmBalanceBreakdown(accountId);

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // PAYMENTS WITH ACTIVITY LOGGING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> sendXlm({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) => paymentService.sendXlm(
    keyPair: keyPair,
    destination: destination,
    amount: amount,
    memoText: memoText,
    onProgress: onProgress,
  );

  Future<String> sendUsdc({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) => paymentService.sendUsdc(
    keyPair: keyPair,
    destination: destination,
    usdcAmount: usdcAmount,
    memoText: memoText,
    onProgress: onProgress,
  );

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // SWAPS WITH ACTIVITY LOGGING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) => swapService.swapXlmToUsdc(
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
  }) => swapService.swapUsdcToXlm(
    keyPair: keyPair,
    sendAmountUsdc: sendAmountUsdc,
    minXlmOut: minXlmOut,
    destination: destination,
    memoText: memoText,
    onProgress: onProgress,
  );

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // CLAIMABLE BALANCES WITH ACTIVITY LOGGING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> createClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required List<Claimant> claimants,
    String? memoText,
    ProgressCallback? onProgress,
  }) => claimableBalanceService.createClaimableBalance(
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
  }) => claimableBalanceService.createUnconditionalClaimableBalance(
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
  }) => claimableBalanceService.createTimeLockedPayment(
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
  }) => claimableBalanceService.createUnconditionalWithExpiry(
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
  }) => claimableBalanceService.createTimeLockedWithExpiry(
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
  }) => claimableBalanceService.claimClaimableBalance(
    keyPair: keyPair,
    balanceId: balanceId,
    onProgress: onProgress,
  );

  Future<List<ClaimableBalanceResponse>> getClaimableBalances({
    required String accountId,
    int limit = 200,
  }) => claimableBalanceService.getClaimableBalances(
    accountId: accountId,
    limit: limit,
  );

  Future<List<ClaimableBalanceResponse>> getSentClaimableBalances({
    required String accountId,
    int limit = 200,
  }) => claimableBalanceService.getSentClaimableBalances(
    accountId: accountId,
    limit: limit,
  );

  Future<Map<String, List<ClaimableBalanceResponse>>> getAllClaimableBalances({
    required String accountId,
    int limit = 200,
  }) => claimableBalanceService.getAllClaimableBalances(
    accountId: accountId,
    limit: limit,
  );

  Future<ClaimableBalanceResponse?> getClaimableBalanceById({
    required String balanceId,
  }) => claimableBalanceService.getClaimableBalanceById(balanceId: balanceId);

  Future<bool> canClaimBalance({
    required String accountId,
    required String balanceId,
  }) => claimableBalanceService.canClaimBalance(
    accountId: accountId,
    balanceId: balanceId,
  );

  /// Ensures a receiver is ready for trade claimable settlement.
  ///
  /// Rules:
  /// - XLM trades: if receiver account is brand-new, activate it first by
  ///   sending a small XLM amount.
  /// - Token trades (USDC/other): receiver account must already exist and must
  ///   have the token trustline; no auto-activation for token flow.
  ///
  /// Returns `true` when activation payment was sent in this call.
  Future<bool> ensureReceiverReadyForClaimable({
    required KeyPair senderKeyPair,
    required String receiverId,
    required Asset tradeAsset,
    double? activationXlmAmount,
    ProgressCallback? onProgress,
  }) async {
    final receiver = receiverId.trim();
    if (receiver.isEmpty) {
      throw StellarWalletError(
        'Receiver wallet address is missing.',
        advice: 'Please refresh and try again.',
        code: 'RECEIVER_EMPTY',
      );
    }

    final exists = await accountService.accountExists(receiver);

    if (tradeAsset is AssetTypeNative) {
      if (exists) return false;
      final activationAmount =
          activationXlmAmount != null && activationXlmAmount > 0
          ? activationXlmAmount
          : await accountService.getLatestAccountActivationMinXlm();
      onProgress?.call('Activating receiver account...');
      await paymentService.sendXlm(
        keyPair: senderKeyPair,
        destination: receiver,
        amount: activationAmount,
        memoText: 'Trade receiver activation',
      );
      onProgress?.call('Verifying receiver activation...');
      var activated = false;
      for (var attempt = 0; attempt < 6; attempt++) {
        if (await accountService.accountExists(receiver)) {
          activated = true;
          break;
        }
        await Future.delayed(Duration(milliseconds: 900 + (attempt * 300)));
      }
      if (!activated) {
        throw StellarWalletError(
          'Receiver activation is not confirmed yet.',
          advice:
              '1 XLM activation was not confirmed in time, so claimable lock was not sent. Please try Lock again in a few seconds.',
          code: 'RECEIVER_ACTIVATION_UNCONFIRMED',
        );
      }
      return true;
    }

    if (!exists) {
      throw StellarWalletError(
        'Receiver account is not activated yet.',
        advice:
            'Activate the receiver wallet with at least 1 XLM first, then add ${_assetCodeLabel(tradeAsset)} trustline.',
        code: 'RECEIVER_NOT_ACTIVATED',
      );
    }

    final hasTrustline = await accountService.hasTrustline(
      receiver,
      tradeAsset,
    );
    if (!hasTrustline) {
      throw StellarWalletError(
        'Receiver wallet cannot receive ${_assetCodeLabel(tradeAsset)} yet.',
        advice:
            'Please add ${_assetCodeLabel(tradeAsset)} trustline on the receiver wallet, then try again.',
        code: 'RECEIVER_TRUSTLINE_MISSING',
      );
    }

    return false;
  }

  String _assetCodeLabel(Asset asset) {
    if (asset is AssetTypeNative) return 'XLM';
    if (asset is AssetTypeCreditAlphaNum) return asset.code.toUpperCase();
    return 'this asset';
  }

  Future<double> getLatestReceiverActivationXlm({bool forceRefresh = false}) =>
      accountService.getLatestAccountActivationMinXlm(
        forceRefresh: forceRefresh,
      );

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // DEX TRADING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> createSellOffer({
    required KeyPair keyPair,
    required Asset selling,
    required Asset buying,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) => dexService.createSellOffer(
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
  }) => dexService.createBuyOffer(
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
  }) => dexService.cancelOffer(
    keyPair: keyPair,
    offerId: offerId,
    selling: selling,
    buying: buying,
    onProgress: onProgress,
  );

  Future<List<OfferResponse>> getAccountOffers({
    required String accountId,
    int limit = 200,
  }) => dexService.getAccountOffers(accountId: accountId, limit: limit);

  Future<OrderBookResponse> getOrderBook({
    required Asset selling,
    required Asset buying,
    int limit = 20,
  }) => dexService.getOrderBook(selling: selling, buying: buying, limit: limit);

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // FEE & QUOTES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<String> getTransactionFeeAddress() => feeService.getSwapFeeAddress();
  Future<int> getCurrentFeeStroops() => feeService.getCurrentFeeStroops();
  Future<double> getCurrentFeeXlm() => feeService.getCurrentFeeXlm();
  Future<String> getCurrentFeeLabel() => feeService.getCurrentFeeLabel();
  Future<void> ensureSwapFeeConfigLoaded({bool refresh = false}) async {
    await feeService.ensureFeeConfigLoaded(refresh: refresh);
  }

  Future<double> estimateNetworkFeeXlm({
    int opCount = 1,
    int percentile = 90,
  }) => feeService.estimateNetworkFeeXlm(
    opCount: opCount,
    percentile: percentile,
  );

  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) => feeService.quoteStrictSend(
    sourceAsset: sourceAsset,
    sourceAmount: sourceAmount,
    destinationAssets: destinationAssets,
  );

  Future<double?> quoteXlmToUsdc(double sendAmountXlm) =>
      feeService.quoteXlmToUsdc(sendAmountXlm);
  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) =>
      feeService.quoteUsdcToXlm(sendAmountUsdc);

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STREAMS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Stream<PaymentOperationResponse> paymentsStream(String accountId) =>
      streamService.paymentsStream(accountId);

  Stream<AccountState> accountStateStream(String accountId) =>
      streamService.accountStateStream(accountId);

  Stream<FeeEstimate> feeEstimateStream({
    int opCount = 1,
    int percentile = 90,
  }) =>
      streamService.feeEstimateStream(opCount: opCount, percentile: percentile);

  Stream<PairPrice> xlmUsdcPriceStream() => streamService.xlmUsdcPriceStream();

  Stream<double> quoteXlmToUsdcStream(double sendAmountXlm) =>
      streamService.quoteXlmToUsdcStream(sendAmountXlm);

  Stream<double> quoteUsdcToXlmStream(double sendAmountUsdc) =>
      streamService.quoteUsdcToXlmStream(sendAmountUsdc);
}
