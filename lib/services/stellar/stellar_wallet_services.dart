// lib/services/stellar/stellar_wallet_services.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:next_fi/services/stellar/stellar_ramp_service.dart';
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

// Import activity logging
import 'package:next_fi/features/activity/model/activity_log.dart';
import 'package:next_fi/features/activity/view_model/activity_log_vm.dart';
import 'package:next_fi/features/activity/view/widgets/activity_notification.dart';

export 'package:next_fi/services/stellar/stellar_base_service.dart'
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
/// - On-ramp/off-ramp integration with third-party providers
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

  // Activity logging (optional)
  ActivityLogVM? _activityVM;
  BuildContext? _context;

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
    ActivityLogVM? activityVM,
    BuildContext? context,
  })  : sdk = testnet ? StellarSDK.TESTNET : StellarSDK.PUBLIC,
        configVault = configVault ?? TransactionFeeVaultSecureStorage(),
        _activityVM = activityVM,
        _context = context,
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

  /// Enable activity logging (call this to activate logging features)
  void enableActivityLogging(ActivityLogVM activityVM, {BuildContext? context}) {
    _activityVM = activityVM;
    _context = context;
  }

  /// Disable activity logging
  void disableActivityLogging() {
    _activityVM = null;
    _context = null;
  }

  /// Check if activity logging is enabled
  bool get isActivityLoggingEnabled => _activityVM != null;

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVITY LOGGING HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _showNotification(ActivityLog log) {
    if (_context != null && _context!.mounted && _activityVM?.settings.showNotifications == true) {
      ActivityNotificationManager.show(_context!, log);
    }
  }

  Future<void> _logActivity(ActivityLog log) async {
    if (_activityVM != null) {
      await _activityVM!.addLog(log);
    }
  }

  Future<void> _updateActivity(
      String id, {
        ActivityStatus? status,
        String? txHash,
        String? errorMessage,
        String? errorAdvice,
        String? description,
      }) async {
    if (_activityVM != null) {
      await _activityVM!.updateLog(
        id,
        status: status,
        txHash: txHash,
        errorMessage: errorMessage,
        errorAdvice: errorAdvice,
        description: description,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ON-RAMP / OFF-RAMP SERVICES WITH ACTIVITY LOGGING
  // ══════════════════════════════════════════════════════════════════════════

  /// Buy XLM using third-party provider
  Future<DeepLinkResult> buyXlmWithProvider({
    required String stellarAddress,
    required RampProvider provider,
    double? amount,
    FiatCurrency? currency,
  }) async {
    String? activityId;

    try {
      // Log ramp activity if enabled
      if (_activityVM != null) {
        final providerName = provider.name;
        final amountStr = amount != null ? '${amount.toStringAsFixed(2)} XLM' : 'XLM';

        final log = ActivityLog(
          id: _activityVM!.generateId(),
          type: ActivityType.info,
          status: ActivityStatus.processing,
          timestamp: DateTime.now(),
          title: 'Opening $providerName',
          description: 'Buy $amountStr with ${currency?.code ?? 'fiat'}',
          metadata: {
            'provider': provider.name,
            'action': 'buy',
            'amount': amount,
            'currency': currency?.code,
            'address': stellarAddress,
          },
        );

        activityId = log.id;
        await _logActivity(log);
        _showNotification(log);
      }

      // Open provider
      final result = await StellarRampDeepLinkService.openProvider(
        provider: provider,
        type: RampTransactionType.buy,
        stellarAddress: stellarAddress,
        amount: amount,
        currency: currency,
      );

      // Update activity
      if (activityId != null) {
        if (result.success) {
          await _updateActivity(
            activityId,
            status: ActivityStatus.completed,
            description: '${provider.name} opened successfully',
          );
        } else {
          await _updateActivity(
            activityId,
            status: ActivityStatus.failed,
            errorMessage: result.errorMessage ?? 'Failed to open provider',
          );
        }

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return result;
    } catch (e) {
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: 'Error: $e',
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      return DeepLinkResult.failure('Error: $e');
    }
  }

  /// Sell XLM using third-party provider
  Future<DeepLinkResult> sellXlmWithProvider({
    required String stellarAddress,
    required RampProvider provider,
    double? amount,
    FiatCurrency? currency,
  }) async {
    String? activityId;

    try {
      if (_activityVM != null) {
        final providerName = provider.name;
        final amountStr = amount != null ? '${amount.toStringAsFixed(2)} XLM' : 'XLM';

        final log = ActivityLog(
          id: _activityVM!.generateId(),
          type: ActivityType.info,
          status: ActivityStatus.processing,
          timestamp: DateTime.now(),
          title: 'Opening $providerName',
          description: 'Sell $amountStr for ${currency?.code ?? 'fiat'}',
          metadata: {
            'provider': provider.name,
            'action': 'sell',
            'amount': amount,
            'currency': currency?.code,
            'address': stellarAddress,
          },
        );

        activityId = log.id;
        await _logActivity(log);
        _showNotification(log);
      }

      final result = await StellarRampDeepLinkService.openProvider(
        provider: provider,
        type: RampTransactionType.sell,
        stellarAddress: stellarAddress,
        amount: amount,
        currency: currency,
      );

      if (activityId != null) {
        if (result.success) {
          await _updateActivity(
            activityId,
            status: ActivityStatus.completed,
            description: '${provider.name} opened successfully',
          );
        } else {
          await _updateActivity(
            activityId,
            status: ActivityStatus.failed,
            errorMessage: result.errorMessage ?? 'Failed to open provider',
          );
        }

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return result;
    } catch (e) {
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: 'Error: $e',
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      return DeepLinkResult.failure('Error: $e');
    }
  }

  /// Swap assets on third-party DEX
  Future<DeepLinkResult> swapOnDex({
    required String stellarAddress,
    required RampProvider provider,
  }) async {
    String? activityId;

    try {
      if (_activityVM != null) {
        final log = ActivityLog(
          id: _activityVM!.generateId(),
          type: ActivityType.info,
          status: ActivityStatus.processing,
          timestamp: DateTime.now(),
          title: 'Opening ${provider.name}',
          description: 'Swap assets on DEX',
          metadata: {
            'provider': provider.name,
            'action': 'swap',
            'address': stellarAddress,
          },
        );

        activityId = log.id;
        await _logActivity(log);
        _showNotification(log);
      }

      final result = await StellarRampDeepLinkService.openProvider(
        provider: provider,
        type: RampTransactionType.swap,
        stellarAddress: stellarAddress,
      );

      if (activityId != null) {
        if (result.success) {
          await _updateActivity(
            activityId,
            status: ActivityStatus.completed,
            description: '${provider.name} opened successfully',
          );
        } else {
          await _updateActivity(
            activityId,
            status: ActivityStatus.failed,
            errorMessage: result.errorMessage ?? 'Failed to open provider',
          );
        }

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return result;
    } catch (e) {
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: 'Error: $e',
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      return DeepLinkResult.failure('Error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Ramp Service Helper Methods (Direct Access)
  // ──────────────────────────────────────────────────────────────────────────

  /// Get provider information
  ProviderInfo? getRampProviderInfo(RampProvider provider) {
    return StellarRampDeepLinkService.getProviderInfo(provider);
  }

  /// Get available providers for specific criteria
  List<ProviderInfo> getAvailableRampProviders({
    RampTransactionType? type,
    FiatCurrency? currency,
    String? region,
  }) {
    return StellarRampDeepLinkService.getAvailableProviders(
      type: type,
      currency: currency,
      region: region,
    );
  }

  /// Check if provider app is installed
  Future<bool> isRampProviderInstalled(RampProvider provider) {
    return StellarRampDeepLinkService.isProviderInstalled(provider);
  }

  /// Get recommended provider
  RampProvider getRecommendedRampProvider({
    required RampTransactionType type,
    FiatCurrency? currency,
    String? region,
  }) {
    return StellarRampDeepLinkService.getRecommendedProvider(
      type: type,
      currency: currency,
      region: region,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MNEMONIC & WALLET MANAGEMENT
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
  // BALANCES & TRUSTLINES
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
      {required KeyPair keyPair, String limit = '922337203685.4775807'}) async {
    String? activityId;

    try {
      // Log activity if enabled
      if (_activityVM != null) {
        final log = ActivityLog.trustline(
          id: _activityVM!.generateId(),
          isAdding: true,
          assetCode: 'USDC',
          issuer: usdcIssuer,
          status: ActivityStatus.processing,
        );
        activityId = log.id;
        await _logActivity(log);
        _showNotification(log);
      }

      final hash = await accountService.createUsdcTrustline(
        keyPair: keyPair,
        limit: limit,
      );

      // Update activity on success
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hash,
          description: 'USDC enabled',
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      return hash;
    } catch (e) {
      // Update activity on error
      if (activityId != null) {
        String errorMsg = 'Failed to add USDC';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

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

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENTS WITH ACTIVITY LOGGING
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<String>> sendXlmWithFee({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    String? activityId;

    try {
      // Log activity if enabled
      if (_activityVM != null) {
        activityId = await _activityVM!.logPayment(
          isSending: true,
          amount: amount,
          asset: 'XLM',
          fromAddress: keyPair.accountId,
          toAddress: destination,
          status: ActivityStatus.processing,
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      // Execute payment with progress tracking
      final hashes = await paymentService.sendXlmWithFee(
        keyPair: keyPair,
        destination: destination,
        amount: amount,
        memoText: memoText,
        onProgress: (message) {
          if (activityId != null) {
            _updateActivity(activityId, description: message);
          }
          onProgress?.call(message);
        },
      );

      // Update activity on success
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hashes.first,
          description: 'Payment sent successfully',
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return hashes;
    } catch (e) {
      // Update activity on error
      if (activityId != null) {
        String errorMsg = 'Payment failed';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

  Future<List<String>> sendUsdcWithFee({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    String? activityId;

    try {
      // Log activity if enabled
      if (_activityVM != null) {
        activityId = await _activityVM!.logPayment(
          isSending: true,
          amount: usdcAmount,
          asset: 'USDC',
          fromAddress: keyPair.accountId,
          toAddress: destination,
          status: ActivityStatus.processing,
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      final hashes = await paymentService.sendUsdcWithFee(
        keyPair: keyPair,
        destination: destination,
        usdcAmount: usdcAmount,
        memoText: memoText,
        onProgress: (message) {
          if (activityId != null) {
            _updateActivity(activityId, description: message);
          }
          onProgress?.call(message);
        },
      );

      // Update activity on success
      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hashes.first,
          description: 'Payment sent successfully',
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return hashes;
    } catch (e) {
      // Update activity on error
      if (activityId != null) {
        String errorMsg = 'Payment failed';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SWAPS WITH ACTIVITY LOGGING
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    String? activityId;

    try {
      if (_activityVM != null) {
        activityId = await _activityVM!.logSwap(
          sendAmount: sendAmountXlm,
          sendAsset: 'XLM',
          receiveAmount: minUsdcOut,
          receiveAsset: 'USDC',
          status: ActivityStatus.processing,
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      final hash = await swapService.swapXlmToUsdc(
        keyPair: keyPair,
        sendAmountXlm: sendAmountXlm,
        minUsdcOut: minUsdcOut,
        destination: destination,
        memoText: memoText,
        onProgress: (message) {
          if (activityId != null) {
            _updateActivity(activityId, description: message);
          }
          onProgress?.call(message);
        },
      );

      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hash,
          description: 'Swap completed successfully',
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return hash;
    } catch (e) {
      if (activityId != null) {
        String errorMsg = 'Swap failed';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

  Future<String> swapUsdcToXlm({
    required KeyPair keyPair,
    required double sendAmountUsdc,
    required double minXlmOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    String? activityId;

    try {
      if (_activityVM != null) {
        activityId = await _activityVM!.logSwap(
          sendAmount: sendAmountUsdc,
          sendAsset: 'USDC',
          receiveAmount: minXlmOut,
          receiveAsset: 'XLM',
          status: ActivityStatus.processing,
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      final hash = await swapService.swapUsdcToXlm(
        keyPair: keyPair,
        sendAmountUsdc: sendAmountUsdc,
        minXlmOut: minXlmOut,
        destination: destination,
        memoText: memoText,
        onProgress: (message) {
          if (activityId != null) {
            _updateActivity(activityId, description: message);
          }
          onProgress?.call(message);
        },
      );

      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hash,
          description: 'Swap completed successfully',
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return hash;
    } catch (e) {
      if (activityId != null) {
        String errorMsg = 'Swap failed';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLAIMABLE BALANCES WITH ACTIVITY LOGGING
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
  }) async {
    String? activityId;

    try {
      final assetCode = asset is AssetTypeCreditAlphaNum ? asset.code : 'XLM';

      if (_activityVM != null) {
        activityId = await _activityVM!.logClaimable(
          isCreating: true,
          amount: amount,
          asset: assetCode,
          recipientAddress: recipientId,
          status: ActivityStatus.processing,
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      final hash = await claimableBalanceService.createUnconditionalClaimableBalance(
        keyPair: keyPair,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        onProgress: (message) {
          if (activityId != null) {
            _updateActivity(activityId, description: message);
          }
          onProgress?.call(message);
        },
      );

      if (activityId != null) {
        await _updateActivity(
          activityId,
          status: ActivityStatus.completed,
          txHash: hash,
          description: 'Claimable balance created',
        );

        final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
        _showNotification(log);
      }

      return hash;
    } catch (e) {
      if (activityId != null) {
        String errorMsg = 'Failed to create claimable balance';
        String? errorAdvice;

        if (e is StellarWalletError) {
          errorMsg = e.message;
          errorAdvice = e.advice;
        }

        await _updateActivity(
          activityId,
          status: ActivityStatus.failed,
          errorMessage: errorMsg,
          errorAdvice: errorAdvice,
        );

        if (_activityVM != null) {
          final log = _activityVM!.logs.firstWhere((l) => l.id == activityId);
          _showNotification(log);
        }
      }

      rethrow;
    }
  }

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
  // DEX TRADING
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
  // FEE & QUOTES
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
  // STREAMS
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