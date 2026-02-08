// StellarWalletServices.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/wallet_models.dart';
import 'package:next_fi/services/stellar/soroban_rpc.dart';
import 'package:next_fi/services/profit_address_vault_secure_storage.dart';

/// Callback for progress updates during operations
typedef ProgressCallback = void Function(String message);

/// User-friendly error with actionable advice
class StellarWalletError implements Exception {
  /// User-friendly message
  final String message;

  /// Technical details for logging/debugging
  final String? technicalDetails;

  /// Actionable advice for the user
  final String? advice;

  /// Error code for programmatic handling
  final String? code;

  StellarWalletError(
      this.message, {
        this.technicalDetails,
        this.advice,
        this.code,
      });

  @override
  String toString() {
    final parts = [message];
    if (advice != null) parts.add('\n$advice');
    return parts.join();
  }

  /// Get full details including technical info
  String toDetailedString() {
    final parts = [message];
    if (advice != null) parts.add('Advice: $advice');
    if (technicalDetails != null) parts.add('Details: $technicalDetails');
    if (code != null) parts.add('Code: $code');
    return parts.join('\n');
  }
}

/// Production-ready Stellar wallet service built on `stellar_flutter_sdk` **v3**.
///
/// **v3 changes applied:**
/// - Mnemonic / HD-wallet helpers now use the SDK's built-in [Wallet] class
///   (SEP-0005) instead of the external `bip39`/`ed25519_hd_key` packages.
/// - `ManageData` value encoding fixed (String → Uint8List via UTF-8).
/// - BigInt used where the v3 migration guide requires it (e.g. `Memo.id`).
///
/// **Core Features:**
/// - Mnemonic generation and validation (using Stellar SDK's Wallet class)
/// - Hierarchical deterministic wallet (BIP-44: m/44'/148'/x')
/// - Multiple account derivation from single mnemonic
/// - Secure key storage with encryption
///
/// **Payment Features:**
/// - CreateAccount vs Payment for XLM sends
/// - USDC payments with trustline management
/// - Automatic trustline creation
/// - Path payments (swaps)
///
/// **Claimable Balances:**
/// - Create time-locked and conditional payments
/// - Claim balances
/// - Query claimable balances
///
/// **Account Management:**
/// - Set account options and data
/// - Trustline management
/// - Account merging
/// - Sponsorship support
///
/// **DEX Trading:**
/// - Create/manage offers
/// - Order book queries
/// - Price streams
class StellarWalletServices {
  final String usdcIssuer;
  final StellarSDK sdk;

  final String? quickNodeUrlMainnet;
  final String? quickNodeUrlTestnet;
  final Map<String, String>? quickNodeDefaultHeaders;
  final StellarSDK? _sdkQuickNode;

  final String? sorobanUrlMainnet;
  final String? sorobanUrlTestnet;
  final Map<String, String>? sorobanDefaultHeaders;
  final SorobanRpc? _soroban;

  final TransactionFeeVaultSecureStorage configVault;
  final FlutterSecureStorage _secureStorage;

  StellarWalletServices({
    required this.usdcIssuer,
    bool testnet = false,
    TransactionFeeVaultSecureStorage? configVault,
    FlutterSecureStorage? secureStorage,
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
        configVault = configVault ?? TransactionFeeVaultSecureStorage(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  bool get _isTestnet => identical(sdk, StellarSDK.TESTNET);
  Network get _network => _isTestnet ? Network.TESTNET : Network.PUBLIC;

  // ──────────────────────────────────────────────────────────────────────────
  // Error Helpers
  // ──────────────────────────────────────────────────────────────────────────

  static String _fmt7(num v) => v.toStringAsFixed(7);

  /// Throw a user-friendly error
  Never _fail(
      String userMessage, {
        Object? technicalError,
        String? advice,
        String? code,
      }) {
    throw StellarWalletError(
      userMessage,
      technicalDetails: technicalError?.toString(),
      advice: advice,
      code: code,
    );
  }

  /// Map Stellar transaction result codes to user-friendly messages
  String _getUserFriendlyTxError(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Not enough funds to complete this transaction';
      case 'tx_bad_seq':
        return 'Transaction timed out';
      case 'tx_insufficient_fee':
        return 'Network fee was too low';
      case 'tx_no_account':
        return 'Account not found on the network';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'Insufficient balance in your account';
          }
          if (ops.contains('op_no_trust')) {
            return 'Recipient hasn\'t added this asset yet';
          }
          if (ops.contains('op_line_full')) {
            return 'Recipient\'s account is at maximum capacity for this asset';
          }
          if (ops.contains('op_no_destination')) {
            return 'Recipient account doesn\'t exist';
          }
        }
        return 'Transaction could not be completed';
      case 'tx_too_late':
        return 'Transaction expired - took too long to process';
      case 'tx_too_early':
        return 'Transaction submitted too early';
      default:
        return 'Transaction failed';
    }
  }

  /// Get actionable advice for transaction errors
  String? _getTxErrorAdvice(String code, List<String>? ops) {
    switch (code) {
      case 'tx_insufficient_balance':
        return 'Check your balance and try sending a smaller amount';
      case 'tx_bad_seq':
        return 'Please wait a moment and try again. This happens when multiple transactions are sent at once';
      case 'tx_insufficient_fee':
        return 'The app will automatically use the correct fee when you try again';
      case 'tx_no_account':
        return 'Make sure you\'re connected to the correct network (mainnet or testnet)';
      case 'tx_failed':
        if (ops != null) {
          if (ops.contains('op_underfunded')) {
            return 'You need more funds to complete this transaction, including network fees';
          }
          if (ops.contains('op_no_trust')) {
            return 'Ask the recipient to add this asset to their wallet first';
          }
          if (ops.contains('op_line_full')) {
            return 'The recipient needs to reduce their balance of this asset before receiving more';
          }
          if (ops.contains('op_no_destination')) {
            return 'The recipient needs to create their Stellar account first';
          }
        }
        return 'Please check your transaction details and try again';
      case 'tx_too_late':
      case 'tx_too_early':
        return 'Please try again - the network timing will be adjusted automatically';
      default:
        return 'If this problem continues, please contact support';
    }
  }

  /// Handle transaction submission errors with user-friendly messages
  Never _failSubmit(
      SubmitTransactionResponse res, {
        String prefix = 'Transaction failed',
      }) {
    final code = res.extras?.resultCodes?.transactionResultCode ?? 'unknown';
    final ops = res.extras?.resultCodes?.operationsResultCodes;
    final hash = res.hash;

    final userMessage = _getUserFriendlyTxError(code, ops!.cast<String>());
    final technicalDetails = 'Code: $code${ops != null ? ', Operations: ${ops.join(", ")}' : ''}${hash != null ? ', Hash: $hash' : ''}';
    final advice = _getTxErrorAdvice(code, ops.cast<String>());

    throw StellarWalletError(
      userMessage,
      technicalDetails: technicalDetails,
      advice: advice,
      code: code,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Mnemonic & Wallet Management (SDK v3 Wallet – SEP-0005)
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate a 12-word mnemonic using Stellar SDK.
  Future<String> generateMnemonic12() async {
    try {
      return await Wallet.generate12WordsMnemonic();
    } catch (e) {
      _fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  /// Generate a 24-word mnemonic using Stellar SDK.
  Future<String> generateMnemonic24() async {
    try {
      return await Wallet.generate24WordsMnemonic();
    } catch (e) {
      _fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  /// Generate a mnemonic with custom word count.
  Future<String> generateMnemonic({int wordCount = 12}) async {
    try {
      switch (wordCount) {
        case 12:
          return await Wallet.generate12WordsMnemonic();
        case 18:
          return await Wallet.generate18WordsMnemonic();
        case 24:
          return await Wallet.generate24WordsMnemonic();
        default:
          return await Wallet.generate12WordsMnemonic();
      }
    } catch (e) {
      _fail(
        'Unable to generate recovery phrase',
        technicalError: e,
        advice: 'Please try again. If the problem persists, restart the app',
      );
    }
  }

  /// Validate a mnemonic phrase.
  Future<bool> validateMnemonic(String mnemonic) async {
    try {
      return await Wallet.validate(mnemonic);
    } catch (_) {
      return false;
    }
  }

  /// Create a [Wallet] instance from a mnemonic.
  Future<Wallet> createWallet(String mnemonic, {String passphrase = ''}) async {
    try {
      return await Wallet.from(mnemonic, passphrase: passphrase);
    } catch (e) {
      _fail(
        'Invalid recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again. Make sure all words are spelled correctly',
      );
    }
  }

  /// Get keypair at specific [index] from mnemonic.
  /// Uses Stellar derivation path: m/44'/148'/index'
  Future<KeyPair> getKeyPairFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
      return await wallet.getKeyPair(index: index);
    } catch (e) {
      _fail(
        'Unable to derive account from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );
    }
  }

  /// Get account ID at specific [index] without full keypair.
  Future<String> getAccountIdFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
      return await wallet.getAccountId(index: index);
    } catch (e) {
      _fail(
        'Unable to derive account from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );
    }
  }

  /// Derive multiple accounts from mnemonic.
  Future<List<KeyPair>> deriveAccounts(
      String mnemonic, {
        required int count,
        String passphrase = '',
      }) async {
    try {
      final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
      final accounts = <KeyPair>[];

      for (int i = 0; i < count; i++) {
        accounts.add(await wallet.getKeyPair(index: i));
      }

      return accounts;
    } catch (e) {
      _fail(
        'Unable to derive accounts from recovery phrase',
        technicalError: e,
        advice: 'Please check your recovery phrase and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Secure Storage
  // ──────────────────────────────────────────────────────────────────────────

  /// Store mnemonic securely.
  Future<void> storeMnemonic(String mnemonic, {String key = 'stellar_mnemonic'}) async {
    try {
      await _secureStorage.write(key: key, value: mnemonic);
    } catch (e) {
      _fail(
        'Unable to save recovery phrase securely',
        technicalError: e,
        advice: 'Please check your device storage permissions and try again',
      );
    }
  }

  /// Retrieve stored mnemonic.
  Future<String?> retrieveMnemonic({String key = 'stellar_mnemonic'}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      _fail(
        'Unable to retrieve recovery phrase',
        technicalError: e,
        advice: 'Please check your device security settings',
      );
    }
  }

  /// Delete stored mnemonic.
  Future<void> deleteMnemonic({String key = 'stellar_mnemonic'}) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      _fail(
        'Unable to delete recovery phrase',
        technicalError: e,
        advice: 'Please try again or restart the app',
      );
    }
  }

  /// Store keypair secret seed securely.
  Future<void> storeSecretSeed(
      String secretSeed, {
        String key = 'stellar_secret',
      }) async {
    try {
      await _secureStorage.write(key: key, value: secretSeed);
    } catch (e) {
      _fail(
        'Unable to save secret key securely',
        technicalError: e,
        advice: 'Please check your device storage permissions and try again',
      );
    }
  }

  /// Retrieve stored secret seed.
  Future<String?> retrieveSecretSeed({String key = 'stellar_secret'}) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      _fail(
        'Unable to retrieve secret key',
        technicalError: e,
        advice: 'Please check your device security settings',
      );
    }
  }

  /// Create keypair from stored secret.
  Future<KeyPair?> getKeyPairFromStorage({String key = 'stellar_secret'}) async {
    try {
      final secret = await _secureStorage.read(key: key);
      if (secret == null) return null;
      return KeyPair.fromSecretSeed(secret);
    } catch (e) {
      _fail(
        'Unable to load account key',
        technicalError: e,
        advice: 'Your account key may be invalid. Please check your settings',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Assets
  // ──────────────────────────────────────────────────────────────────────────
  Asset get _xlm => Asset.NATIVE;
  Asset get _usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  static const double _kTxFeeUsdc = 0.005;

  String get horizonBase =>
      _isTestnet ? 'https://horizon-testnet.stellar.org' : 'https://horizon.stellar.org';
  String? get _qnBase => _isTestnet ? quickNodeUrlTestnet : quickNodeUrlMainnet;

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP with fallback
  // ──────────────────────────────────────────────────────────────────────────
  Future<dynamic> _getWithFallback(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final primary = Uri.parse('$horizonBase$path').replace(queryParameters: query);
    try {
      final r = await sdk.httpClient.get(primary).timeout(timeout);
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

  Future<dynamic> _tryQuickNode(
      String path, {
        Map<String, String>? query,
        Duration timeout = const Duration(seconds: 20),
      }) async {
    final base = _qnBase;
    if (base == null || base.isEmpty) return null;
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    try {
      if (_sdkQuickNode != null) {
        return await _sdkQuickNode!.httpClient.get(uri).timeout(timeout);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Account Management
  // ──────────────────────────────────────────────────────────────────────────
  Future<AccountResponse> _loadAccount(String accountId) async {
    try {
      return await sdk.accounts.account(accountId);
    } catch (e) {
      _fail(
        'Unable to load account information',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  bool get isTestnet => _isTestnet;

  Future<String> getTransactionFeeAddress() async {
    try {
      return (await configVault.readOrInit()).address;
    } catch (e) {
      _fail(
        'Unable to load fee settings',
        technicalError: e,
        advice: 'Please restart the app. If the problem continues, you may need to reinstall',
      );
    }
  }

  int _toStroops(double amount) => (amount * 1e7).round();
  double _fromStroops(int stroops) => stroops / 1e7;

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
      return 0.05;
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

  Future<bool> _accountExists(String accountId) async {
    try {
      await _loadAccount(accountId);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _toClassicAccountId(String addr) {
    final a = addr.trim();
    if (a.isEmpty) {
      _fail(
        'Please enter a valid Stellar address',
        code: 'EMPTY_ADDRESS',
        advice: 'Stellar addresses start with "G" and are 56 characters long',
      );
    }
    if (a.startsWith('G') && a.length >= 56) {
      return a;
    }
    if (a.startsWith('M')) {
      _fail(
        'This address format isn\'t supported yet',
        technicalError: 'Muxed address (M...) provided',
        advice: 'Please use a standard Stellar address (starts with "G") and add a memo if needed',
        code: 'MUXED_ADDRESS',
      );
    }
    _fail(
      'This doesn\'t look like a valid Stellar address',
      technicalError: 'Invalid format: $a',
      advice: 'Stellar addresses start with "G" and are 56 characters long. Please check and try again',
      code: 'INVALID_ADDRESS',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Balances
  // ──────────────────────────────────────────────────────────────────────────
  Future<double> getXlmBalance(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) return double.parse(b.balance);
      }
      return 0.0;
    } catch (e) {
      _fail(
        'Unable to fetch XLM balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
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
      _fail(
        'Unable to fetch USDC balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getAssetBalance(String accountId, Asset asset) async {
    try {
      final acc = await _loadAccount(accountId);

      if (asset is AssetTypeNative) {
        for (final b in acc.balances) {
          if (b.assetType == Asset.TYPE_NATIVE) return double.parse(b.balance);
        }
        return 0.0;
      }

      if (asset is AssetTypeCreditAlphaNum) {
        for (final b in acc.balances) {
          if (b.assetCode == asset.code && b.assetIssuer == asset.issuerId) {
            return double.parse(b.balance);
          }
        }
        return 0.0;
      }

      return 0.0;
    } catch (e) {
      _fail(
        'Unable to fetch balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  /// Get all balances for an account.
  Future<List<Balance>> getAllBalances(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      return acc.balances;
    } catch (e) {
      _fail(
        'Unable to fetch account balances',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Trustlines
  // ──────────────────────────────────────────────────────────────────────────
  Future<bool> hasUsdcTrustline(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      return acc.balances
          .any((b) => b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer);
    } catch (e) {
      _fail(
        'Unable to check USDC status',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<bool> hasTrustline(String accountId, Asset asset) async {
    try {
      if (asset is AssetTypeNative) return true;

      final acc = await _loadAccount(accountId);
      if (asset is AssetTypeCreditAlphaNum) {
        return acc.balances.any(
              (b) => b.assetCode == asset.code && b.assetIssuer == asset.issuerId,
        );
      }
      return false;
    } catch (e) {
      _fail(
        'Unable to check asset status',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> createUsdcTrustline({
    required KeyPair keyPair,
    String limit = '922337203685.4775807',
  }) async {
    try {
      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(_usdc, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to add USDC');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to add USDC to your wallet',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> createTrustline({
    required KeyPair keyPair,
    required Asset asset,
    String limit = '922337203685.4775807',
  }) async {
    try {
      if (asset is AssetTypeNative) {
        _fail(
          'XLM is already in your wallet',
          advice: 'You don\'t need to add XLM - it\'s the native Stellar currency',
          code: 'NATIVE_ASSET',
        );
      }

      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to add asset');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to add asset to your wallet',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> removeTrustline({
    required KeyPair keyPair,
    required Asset asset,
  }) async {
    try {
      if (asset is AssetTypeNative) {
        _fail(
          'XLM cannot be removed',
          advice: 'XLM is the native Stellar currency and is always in your wallet',
          code: 'NATIVE_ASSET',
        );
      }

      final balance = await getAssetBalance(keyPair.accountId, asset);
      if (balance > 0) {
        _fail(
          'Can\'t remove this asset yet',
          technicalError: 'Current balance: ${_fmt7(balance)}',
          advice: 'You need to send or swap all your funds before removing this asset from your wallet',
          code: 'NON_ZERO_BALANCE',
        );
      }

      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, '0').build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to remove asset');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to remove asset from your wallet',
        technicalError: e,
        advice: 'Please try again. If the problem persists, check your internet connection',
      );
    }
  }

  Future<void> _ensureUsdcTrustlineSelf(
      KeyPair keyPair, {
        String limit = '922337203685.4775807',
        ProgressCallback? onProgress,
      }) async {
    if (await hasUsdcTrustline(keyPair.accountId)) return;
    onProgress?.call('Setting up USDC in your wallet...');
    await createUsdcTrustline(keyPair: keyPair, limit: limit);
  }

  Future<void> _ensureTrustline(
      KeyPair keyPair,
      Asset asset, {
        String limit = '922337203685.4775807',
        ProgressCallback? onProgress,
      }) async {
    if (await hasTrustline(keyPair.accountId, asset)) return;

    final assetName = asset is AssetTypeCreditAlphaNum ? asset.code : 'asset';
    onProgress?.call('Setting up $assetName in your wallet...');
    await createTrustline(keyPair: keyPair, asset: asset, limit: limit);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Claimable Balances
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> createClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required List<Claimant> claimants,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (amount <= 0) {
      _fail(
        'Invalid amount entered',
        technicalError: 'Amount: $amount',
        advice: 'Please enter an amount greater than 0',
        code: 'INVALID_AMOUNT',
      );
    }
    if (claimants.isEmpty) {
      _fail(
        'No recipient specified',
        technicalError: 'Claimants list is empty',
        advice: 'Please add at least one recipient who can claim this payment',
        code: 'NO_CLAIMANTS',
      );
    }

    try {
      if (asset is! AssetTypeNative) {
        await _ensureTrustline(keyPair, asset, onProgress: onProgress);
      }

      onProgress?.call('Checking balance...');
      final balance = await getAssetBalance(keyPair.accountId, asset);
      if (balance < amount) {
        final assetName = asset is AssetTypeCreditAlphaNum ? asset.code : 'XLM';
        _fail(
          'Not enough $assetName in your wallet',
          technicalError: 'Have: ${_fmt7(balance)}, Need: ${_fmt7(amount)}',
          advice: 'You need ${_fmt7(amount - balance)} more $assetName to create this payment',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Creating claimable payment...');
      final acc = await _loadAccount(keyPair.accountId);

      final tb = TransactionBuilder(acc)
        ..setMaxOperationFee(100)
        ..addOperation(
          CreateClaimableBalanceOperationBuilder(
            claimants,
            asset,
            _fmt7(amount),
          ).build(),
        );

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to create payment');

      onProgress?.call('Payment created successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to create claimable payment',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> claimClaimableBalance({
    required KeyPair keyPair,
    required String balanceId,
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call('Claiming payment...');
      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ClaimClaimableBalanceOperationBuilder(balanceId).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to claim payment');

      onProgress?.call('Payment claimed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to claim payment',
        technicalError: e,
        advice: 'The payment may have expired or already been claimed. Please check and try again',
      );
    }
  }

  /// Get claimable balances that this account can claim (received)
  Future<List<ClaimableBalanceResponse>> getClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.claimableBalances
          .forClaimant(accountId)
          .limit(limit)
          .execute();
      return page.records ?? [];
    } catch (e) {
      _fail(
        'Unable to fetch claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  /// Get claimable balances created by this account (sent)
  Future<List<ClaimableBalanceResponse>> getSentClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.claimableBalances
          .forSponsor(accountId)
          .limit(limit)
          .execute();
      return page.records ?? [];
    } catch (e) {
      _fail(
        'Unable to fetch sent claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  /// Get all claimable balances (both sent and received)
  Future<Map<String, List<ClaimableBalanceResponse>>> getAllClaimableBalances({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final received = await getClaimableBalances(
        accountId: accountId,
        limit: limit,
      );
      final sent = await getSentClaimableBalances(
        accountId: accountId,
        limit: limit,
      );

      return {
        'received': received,
        'sent': sent,
      };
    } catch (e) {
      _fail(
        'Unable to fetch claimable payments',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  /// Get details of a specific claimable balance by ID
  Future<ClaimableBalanceResponse?> getClaimableBalanceById({
    required String balanceId,
  }) async {
    try {
      return await sdk.claimableBalances.claimableBalance(balanceId as Uri);
    } catch (e) {
      return null;
    }
  }

  /// Check if a claimable balance can be claimed by the account
  Future<bool> canClaimBalance({
    required String accountId,
    required String balanceId,
  }) async {
    try {
      final balance = await getClaimableBalanceById(balanceId: balanceId);
      if (balance == null) return false;

      // Check if account is in the claimants list
      for (final claimant in balance.claimants) {
        if (claimant.destination == accountId) {
          // TODO: Check if predicate conditions are met
          // For now, just check if account is a claimant
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
// ADD these methods to the "Claimable Balances" section of
// StellarWalletServices.dart (alongside existing createTimeLockedPayment, etc.)
// ══════════════════════════════════════════════════════════════════════════

  // ── Expiration-aware claimable balance creators ─────────────────────────

  /// Create an **instant** claimable balance **with expiration**.
  ///
  /// The recipient can claim immediately but must do so before [expiryTime].
  /// After expiry, the sender can reclaim the funds.
  ///
  /// Predicates:
  /// - Recipient: `beforeAbsoluteTime(expiry)` → claim before expiry
  /// - Sender:    `NOT(beforeAbsoluteTime(expiry))` → reclaim after expiry
  Future<String> createUnconditionalWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) async {
    if (expiryTime.isBefore(DateTime.now())) {
      _fail(
        'Expiration time must be in the future',
        advice: 'Choose a date and time after right now',
        code: 'EXPIRY_IN_PAST',
      );
    }

    final expiryTimestamp = expiryTime.millisecondsSinceEpoch ~/ 1000;

    // Recipient can claim any time BEFORE expiry
    final recipientClaimant = Claimant(
      recipientId,
      Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
    );

    // Sender can reclaim AFTER expiry (NOT before expiry = after expiry)
    final senderClaimant = Claimant(
      keyPair.accountId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [recipientClaimant, senderClaimant],
      onProgress: onProgress,
    );
  }

  /// Create a **time-locked** claimable balance **with expiration**.
  ///
  /// The recipient can claim only between [unlockTime] and [expiryTime].
  /// After expiry, the sender can reclaim the funds.
  ///
  /// Predicates:
  /// - Recipient: `AND(NOT(beforeAbsoluteTime(unlock)), beforeAbsoluteTime(expiry))`
  ///              → claim after unlock AND before expiry
  /// - Sender:    `NOT(beforeAbsoluteTime(expiry))` → reclaim after expiry
  Future<String> createTimeLockedWithExpiry({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    required DateTime expiryTime,
    ProgressCallback? onProgress,
  }) async {
    if (unlockTime.isBefore(DateTime.now())) {
      _fail(
        'Unlock time must be in the future',
        advice: 'Choose a date and time after right now',
        code: 'UNLOCK_IN_PAST',
      );
    }

    if (expiryTime.isBefore(unlockTime)) {
      _fail(
        'Expiration must be after unlock time',
        advice: 'The expiration date needs to be after the unlock date so the recipient has a window to claim',
        code: 'EXPIRY_BEFORE_UNLOCK',
      );
    }

    final unlockTimestamp = unlockTime.millisecondsSinceEpoch ~/ 1000;
    final expiryTimestamp = expiryTime.millisecondsSinceEpoch ~/ 1000;

    // Recipient can claim AFTER unlock AND BEFORE expiry
    final recipientClaimant = Claimant(
      recipientId,
      Claimant.predicateAnd(
        Claimant.predicateNot(
          Claimant.predicateBeforeAbsoluteTime(unlockTimestamp),
        ),
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    // Sender can reclaim AFTER expiry
    final senderClaimant = Claimant(
      keyPair.accountId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(expiryTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [recipientClaimant, senderClaimant],
      onProgress: onProgress,
    );
  }
  Future<String> createTimeLockedPayment({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    ProgressCallback? onProgress,
  }) async {
    final unlockTimestamp = unlockTime.millisecondsSinceEpoch ~/ 1000;

    final claimant = Claimant(
      recipientId,
      Claimant.predicateNot(
        Claimant.predicateBeforeAbsoluteTime(unlockTimestamp),
      ),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [claimant],
      onProgress: onProgress,
    );
  }

  Future<String> createUnconditionalClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    ProgressCallback? onProgress,
  }) async {
    final claimant = Claimant(
      recipientId,
      Claimant.predicateUnconditional(),
    );

    return createClaimableBalance(
      keyPair: keyPair,
      asset: asset,
      amount: amount,
      claimants: [claimant],
      onProgress: onProgress,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Account Data
  // ──────────────────────────────────────────────────────────────────────────

  /// Set a data entry on the account.
  ///
  /// [value] is UTF-8 encoded to [Uint8List] before submission
  /// (the SDK's [ManageDataOperationBuilder] expects `Uint8List?`).
  Future<String> setAccountData({
    required KeyPair keyPair,
    required String key,
    required String value,
  }) async {
    try {
      if (key.isEmpty || key.length > 64) {
        _fail(
          'Data key is ${key.isEmpty ? "empty" : "too long"}',
          technicalError: 'Length: ${key.length} characters (max: 64)',
          advice: 'Please use a key between 1 and 64 characters',
          code: 'INVALID_KEY_LENGTH',
        );
      }
      if (value.length > 64) {
        _fail(
          'Data value is too long',
          technicalError: 'Length: ${value.length} characters (max: 64)',
          advice: 'Please shorten your data to 64 characters or less',
          code: 'INVALID_VALUE_LENGTH',
        );
      }

      // Encode the string value to bytes for ManageDataOperationBuilder.
      final Uint8List valueBytes = Uint8List.fromList(utf8.encode(value));

      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ManageDataOperationBuilder(key, valueBytes).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to save data');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to save account data',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> deleteAccountData({
    required KeyPair keyPair,
    required String key,
  }) async {
    try {
      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ManageDataOperationBuilder(key, null).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to delete data');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to delete account data',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String?> getAccountData({
    required String accountId,
    required String key,
  }) async {
    try {
      final acc = await _loadAccount(accountId);
      final dataValue = acc.data?[key];
      if (dataValue == null) return null;

      final decoded = base64.decode(dataValue);
      return utf8.decode(decoded);
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Account Options
  // ──────────────────────────────────────────────────────────────────────────

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
  }) async {
    try {
      final acc = await _loadAccount(keyPair.accountId);

      final builder = SetOptionsOperationBuilder();

      if (homeDomain != null) builder.setHomeDomain(homeDomain);
      if (inflationDestination != null) {
        builder.setInflationDestination(inflationDestination);
      }
      if (lowThreshold != null) builder.setLowThreshold(lowThreshold);
      if (mediumThreshold != null) builder.setMediumThreshold(mediumThreshold);
      if (highThreshold != null) builder.setHighThreshold(highThreshold);
      if (masterWeight != null) builder.setMasterKeyWeight(masterWeight);
      if (setFlags != null) builder.setSetFlags(setFlags);
      if (clearFlags != null) builder.setClearFlags(clearFlags);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(builder.build())
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to update account settings');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to update account settings',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<String> setHomeDomain({
    required KeyPair keyPair,
    required String domain,
  }) async {
    return setAccountOptions(
      keyPair: keyPair,
      homeDomain: domain,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Account Merge
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> mergeAccount({
    required KeyPair keyPair,
    required String destinationId,
    ProgressCallback? onProgress,
  }) async {
    try {
      final dest = _toClassicAccountId(destinationId);

      onProgress?.call('Checking destination account...');
      if (!await _accountExists(dest)) {
        _fail(
          'Destination account doesn\'t exist',
          technicalError: 'Account not found: $dest',
          advice: 'The destination account needs to be active on the Stellar network before you can merge',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      onProgress?.call('Merging accounts...');
      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        AccountMergeOperationBuilder(dest).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to merge accounts');

      onProgress?.call('Accounts merged successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to merge accounts',
        technicalError: e,
        advice: 'Make sure you have no active trustlines, offers, or data entries before merging',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sponsorship
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> sponsorAccount({
    required KeyPair sponsorKeyPair,
    required String sponsoredId,
    required List<Operation> sponsoredOperations,
  }) async {
    try {
      final sponsored = _toClassicAccountId(sponsoredId);
      final acc = await _loadAccount(sponsorKeyPair.accountId);

      final tb = TransactionBuilder(acc)..setMaxOperationFee(100);

      tb.addOperation(
        BeginSponsoringFutureReservesOperationBuilder(sponsored).build(),
      );

      for (final op in sponsoredOperations) {
        tb.addOperation(op);
      }

      tb.addOperation(
        EndSponsoringFutureReservesOperationBuilder()
            .setSourceAccount(sponsored)
            .build(),
      );

      final tx = tb.build();
      tx.sign(sponsorKeyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to sponsor account');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to sponsor account',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DEX Trading
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> createSellOffer({
    required KeyPair keyPair,
    required Asset selling,
    required Asset buying,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) async {
    try {
      await _ensureTrustline(keyPair, selling, onProgress: onProgress);
      await _ensureTrustline(keyPair, buying, onProgress: onProgress);

      onProgress?.call('Creating sell order...');
      final acc = await _loadAccount(keyPair.accountId);

      final builder = ManageSellOfferOperationBuilder(
        selling,
        buying,
        _fmt7(amount),
        _fmt7(price),
      );

      if (offerId != null) {
        builder.setOfferId(offerId.toString());
      }

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(builder.build())
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to create sell order');

      onProgress?.call('Sell order created!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to create sell order',
        technicalError: e,
        advice: 'Please check your balance and internet connection',
      );
    }
  }

  Future<String> createBuyOffer({
    required KeyPair keyPair,
    required Asset buying,
    required Asset selling,
    required double amount,
    required double price,
    int? offerId,
    ProgressCallback? onProgress,
  }) async {
    try {
      await _ensureTrustline(keyPair, selling, onProgress: onProgress);
      await _ensureTrustline(keyPair, buying, onProgress: onProgress);

      onProgress?.call('Creating buy order...');
      final acc = await _loadAccount(keyPair.accountId);

      final builder = ManageBuyOfferOperationBuilder(
        selling,
        buying,
        _fmt7(amount),
        _fmt7(price),
      );

      if (offerId != null) {
        builder.setOfferId(offerId.toString());
      }

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(builder.build())
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to create buy order');

      onProgress?.call('Buy order created!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to create buy order',
        technicalError: e,
        advice: 'Please check your balance and internet connection',
      );
    }
  }

  Future<String> cancelOffer({
    required KeyPair keyPair,
    required int offerId,
    required Asset selling,
    required Asset buying,
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call('Canceling order...');
      final acc = await _loadAccount(keyPair.accountId);

      final builder = ManageSellOfferOperationBuilder(
        selling,
        buying,
        '0',
        '1',
      )..setOfferId(offerId.toString());

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(builder.build())
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Unable to cancel order');

      onProgress?.call('Order canceled!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to cancel order',
        technicalError: e,
        advice: 'The order may have already been filled or canceled',
      );
    }
  }

  Future<List<OfferResponse>> getAccountOffers({
    required String accountId,
    int limit = 200,
  }) async {
    try {
      final page = await sdk.offers
          .forAccount(accountId)
          .limit(limit)
          .execute();
      return page.records ?? [];
    } catch (e) {
      _fail(
        'Unable to fetch open orders',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<OrderBookResponse> getOrderBook({
    required Asset selling,
    required Asset buying,
    int limit = 20,
  }) async {
    try {
      return await sdk.orderBook
          .sellingAsset(selling)
          .buyingAsset(buying)
          .limit(limit)
          .execute();
    } catch (e) {
      _fail(
        'Unable to fetch order book',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Payments
  // ──────────────────────────────────────────────────────────────────────────
  Future<List<String>> sendXlmWithFee({
    required KeyPair keyPair,
    required String destination,
    required double amount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (amount <= 0) {
      _fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $amount',
        advice: 'Try entering an amount like 10 or 25.50',
        code: 'INVALID_AMOUNT',
      );
    }

    try {
      onProgress?.call('Validating address...');
      final dest = _toClassicAccountId(destination);
      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

      onProgress?.call('Calculating fees...');
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);
      final totalStroops = _toStroops(amount);

      if (totalStroops <= feeStroops) {
        _fail(
          'Amount is too small to send',
          technicalError: 'Amount must be greater than fee: ${_fmt7(feeXlm)} XLM',
          advice: 'Please enter an amount greater than ${_fmt7(feeXlm)} XLM to cover the transaction fee',
          code: 'AMOUNT_TOO_SMALL',
        );
      }

      final recvXlm = _fromStroops(totalStroops - feeStroops);

      onProgress?.call('Loading account...');
      final acc = await _loadAccount(keyPair.accountId);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      onProgress?.call('Checking destination...');
      final destExists = await _accountExists(dest);
      if (destExists) {
        tb.addOperation(
          PaymentOperationBuilder(dest, _xlm, _fmt7(recvXlm)).build(),
        );
      } else {
        if (recvXlm < 1.0) {
          _fail(
            'Cannot create new account with this amount',
            technicalError: 'Need 1 XLM minimum, but only ${_fmt7(recvXlm)} XLM available after fees',
            advice: 'New Stellar accounts need at least 1 XLM. Try sending ${_fmt7(1.0 + feeXlm)} XLM or more',
            code: 'INSUFFICIENT_FOR_ACCOUNT_CREATION',
          );
        }
        tb.addOperation(
          CreateAccountOperationBuilder(dest, _fmt7(recvXlm)).build(),
        );
      }

      if (needsFeeOp) {
        tb.addOperation(
          PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
        );
      }

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, _network);

      onProgress?.call('Sending transaction...');
      try {
        final res = await sdk.submitTransaction(tx);
        if (!res.success) _failSubmit(res, prefix: 'Payment failed');
        onProgress?.call('Payment sent successfully!');
        return [res.hash!];
      } catch (e) {
        if (_sdkQuickNode != null) {
          try {
            final res = await _sdkQuickNode!.submitTransaction(tx);
            if (!res.success) _failSubmit(res, prefix: 'Payment failed');
            onProgress?.call('Payment sent successfully!');
            return [res.hash!];
          } catch (_) {
            if (e is StellarWalletError) rethrow;
            _fail(
              'Unable to send payment',
              technicalError: e,
              advice: 'Please check your internet connection and try again',
            );
          }
        }
        rethrow;
      }
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to send XLM',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<List<String>> sendUsdcWithFee({
    required KeyPair keyPair,
    required String destination,
    required double usdcAmount,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (usdcAmount <= 0) {
      _fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $usdcAmount',
        advice: 'Try entering an amount like 10 or 25.50',
        code: 'INVALID_AMOUNT',
      );
    }

    try {
      onProgress?.call('Validating address...');
      final dest = _toClassicAccountId(destination);
      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

      onProgress?.call('Checking destination account...');
      if (!await _accountExists(dest)) {
        _fail(
          'Recipient doesn\'t have a Stellar account yet',
          technicalError: 'Account not found: $dest',
          advice: 'The recipient needs to create their Stellar account first. They can do this by receiving XLM from another wallet or using an exchange',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      await _ensureUsdcTrustlineSelf(keyPair, onProgress: onProgress);

      onProgress?.call('Checking recipient USDC setup...');
      if (!await hasUsdcTrustline(dest)) {
        _fail(
          'Recipient can\'t receive USDC yet',
          technicalError: 'No USDC trustline for: $dest',
          advice: 'The recipient needs to add USDC to their wallet first. This is a one-time setup they can do in their Stellar wallet settings',
          code: 'NO_DESTINATION_TRUSTLINE',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      onProgress?.call('Checking balances...');
      final senderXlmBal = await getXlmBalance(keyPair.accountId);
      if (senderXlmBal < feeXlm) {
        _fail(
          'Not enough XLM for transaction fee',
          technicalError: 'Have: ${_fmt7(senderXlmBal)} XLM, Need: ${_fmt7(feeXlm)} XLM',
          advice: 'You need ${_fmt7(feeXlm - senderXlmBal)} more XLM to pay the transaction fee',
          code: 'INSUFFICIENT_XLM_FOR_FEE',
        );
      }

      final senderUsdcBal = await getUsdcBalance(keyPair.accountId);
      if (senderUsdcBal < usdcAmount) {
        _fail(
          'Not enough USDC in your wallet',
          technicalError: 'Have: ${_fmt7(senderUsdcBal)} USDC, Need: ${_fmt7(usdcAmount)} USDC',
          advice: 'You need ${_fmt7(usdcAmount - senderUsdcBal)} more USDC to complete this transaction',
          code: 'INSUFFICIENT_USDC',
        );
      }

      onProgress?.call('Preparing transaction...');
      final acc = await _loadAccount(keyPair.accountId);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
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

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, _network);

      onProgress?.call('Sending transaction...');
      try {
        final res = await sdk.submitTransaction(tx);
        if (!res.success) _failSubmit(res, prefix: 'Payment failed');
        onProgress?.call('Payment sent successfully!');
        return [res.hash!];
      } catch (e) {
        if (_sdkQuickNode != null) {
          try {
            final res = await _sdkQuickNode!.submitTransaction(tx);
            if (!res.success) _failSubmit(res, prefix: 'Payment failed');
            onProgress?.call('Payment sent successfully!');
            return [res.hash!];
          } catch (_) {
            if (e is StellarWalletError) rethrow;
            _fail(
              'Unable to send payment',
              technicalError: e,
              advice: 'Please check your internet connection and try again',
            );
          }
        }
        rethrow;
      }
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to send USDC',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Swaps
  // ──────────────────────────────────────────────────────────────────────────
  Future<String> swapXlmToUsdc({
    required KeyPair keyPair,
    required double sendAmountXlm,
    required double minUsdcOut,
    String? destination,
    String? memoText,
    ProgressCallback? onProgress,
  }) async {
    if (sendAmountXlm <= 0) {
      _fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $sendAmountXlm',
        advice: 'Try entering an amount like 10 or 25',
        code: 'INVALID_AMOUNT',
      );
    }
    if (minUsdcOut <= 0) {
      _fail(
        'Minimum output must be greater than 0',
        technicalError: 'Min output: $minUsdcOut',
        advice: 'Please set a valid minimum USDC amount to receive',
        code: 'INVALID_MIN_OUTPUT',
      );
    }

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? _toClassicAccountId(destination!.trim())
          : self;

      onProgress?.call('Setting up USDC...');
      await _ensureUsdcTrustlineSelf(keyPair, onProgress: onProgress);

      onProgress?.call('Checking destination...');
      if (!await _accountExists(dest)) {
        _fail(
          'Recipient doesn\'t have a Stellar account yet',
          technicalError: 'Account not found: $dest',
          advice: 'The recipient needs to create their Stellar account first',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      if (!await hasUsdcTrustline(dest)) {
        _fail(
          'Recipient can\'t receive USDC yet',
          technicalError: 'No USDC trustline for: $dest',
          advice: 'The recipient needs to add USDC to their wallet first',
          code: 'NO_DESTINATION_TRUSTLINE',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      onProgress?.call('Checking balance...');
      final senderXlmBal = await getXlmBalance(self);

      const minReserve = 1.5;
      final totalNeeded = sendAmountXlm + feeXlm + minReserve;

      if (senderXlmBal < totalNeeded) {
        _fail(
          'Not enough XLM for this swap',
          technicalError: 'Have: ${_fmt7(senderXlmBal)} XLM | Need: ${_fmt7(totalNeeded)} XLM',
          advice: 'Breakdown: ${_fmt7(sendAmountXlm)} to swap + ${_fmt7(feeXlm)} network fee + ${_fmt7(minReserve)} account reserve. You need ${_fmt7(totalNeeded - senderXlmBal)} more XLM',
          code: 'INSUFFICIENT_BALANCE',
        );
      }

      onProgress?.call('Preparing swap...');
      final acc = await _loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
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

      if (needsFeeOp) {
        tb.addOperation(
          PaymentOperationBuilder(feeAddr, _xlm, _fmt7(feeXlm)).build(),
        );
      }

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, _network);

      onProgress?.call('Executing swap...');
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Swap failed');

      onProgress?.call('Swap completed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to swap XLM to USDC',
        technicalError: e,
        advice: 'The swap may have failed due to price slippage. Try adjusting your minimum output or check market conditions',
      );
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
    if (sendAmountUsdc <= 0) {
      _fail(
        'Please enter a valid amount',
        technicalError: 'Amount: $sendAmountUsdc',
        advice: 'Try entering an amount like 10 or 25',
        code: 'INVALID_AMOUNT',
      );
    }
    if (minXlmOut <= 0) {
      _fail(
        'Minimum output must be greater than 0',
        technicalError: 'Min output: $minXlmOut',
        advice: 'Please set a valid minimum XLM amount to receive',
        code: 'INVALID_MIN_OUTPUT',
      );
    }

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? _toClassicAccountId(destination!.trim())
          : self;

      onProgress?.call('Checking USDC setup...');
      await _ensureUsdcTrustlineSelf(keyPair, onProgress: onProgress);

      onProgress?.call('Checking balance...');
      final senderUsdcBal = await getUsdcBalance(self);
      if (senderUsdcBal < sendAmountUsdc) {
        _fail(
          'Not enough USDC in your wallet',
          technicalError: 'Have: ${_fmt7(senderUsdcBal)} USDC, Need: ${_fmt7(sendAmountUsdc)} USDC',
          advice: 'You need ${_fmt7(sendAmountUsdc - senderUsdcBal)} more USDC to complete this swap',
          code: 'INSUFFICIENT_USDC',
        );
      }

      onProgress?.call('Calculating fees...');
      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      onProgress?.call('Preparing swap...');
      final acc = await _loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        if (minXlmOut < feeXlm) {
          _fail(
            'Swap amount too low to cover fees',
            technicalError: 'Minimum output: ${_fmt7(minXlmOut)} XLM | Fee required: ${_fmt7(feeXlm)} XLM',
            advice: 'The swap needs to receive at least ${_fmt7(feeXlm)} XLM to cover the transaction fee. Try increasing your swap amount',
            code: 'MIN_OUTPUT_TOO_LOW',
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
        final senderXlmBal = await getXlmBalance(self);
        if (senderXlmBal < feeXlm) {
          _fail(
            'Not enough XLM for transaction fee',
            technicalError: 'Have: ${_fmt7(senderXlmBal)} XLM, Need: ${_fmt7(feeXlm)} XLM',
            advice: 'You need ${_fmt7(feeXlm - senderXlmBal)} more XLM to pay the network fee for this swap',
            code: 'INSUFFICIENT_XLM_FOR_FEE',
          );
        }

        onProgress?.call('Checking destination...');
        if (!await _accountExists(dest)) {
          _fail(
            'Recipient doesn\'t have a Stellar account yet',
            technicalError: 'Account not found: $dest',
            advice: 'The recipient needs to create their Stellar account first',
            code: 'DESTINATION_NOT_FOUND',
          );
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

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

      final tx = tb.build();
      tx.sign(keyPair, _network);

      onProgress?.call('Executing swap...');
      final res = await sdk.submitTransaction(tx);
      if (!res.success) {
        _failSubmit(res, prefix: 'Swap failed');
      }

      onProgress?.call('Swap completed successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      _fail(
        'Unable to swap USDC to XLM',
        technicalError: e,
        advice: 'The swap may have failed due to price slippage. Try adjusting your minimum output or check market conditions',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Quotes
  // ──────────────────────────────────────────────────────────────────────────
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
      if (sourceAsset is AssetTypeNative)
        'source_asset_type': 'native',
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
      final resp = await _getWithFallback(
        '/fee_stats',
        timeout: const Duration(seconds: 10),
      );

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

    return (200 * ops) * 1e-7;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Streams
  // ──────────────────────────────────────────────────────────────────────────
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
          if (b.assetType == Asset.TYPE_NATIVE) {
            xlm = double.parse(b.balance);
          }
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
        if (!closed) {
          controller.addError(e, st);
        }
      }
    }

    emitSnapshot();

    Stream<void> _payStream(StellarSDK s) =>
        s.payments.forAccount(accountId).cursor("now").stream().map((_) => null);
    Stream<void> _effStream(StellarSDK s) =>
        s.effects.forAccount(accountId).cursor("now").stream().map((_) => null);

    final pay = _sseWithFallback<void>(_payStream).listen(
          (_) {
        coolDown?.cancel();
        coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
      },
      onError: (e, st) {
        if (!closed) controller.addError(e, st);
      },
    );

    final eff = _sseWithFallback<void>(_effStream).listen(
          (_) {
        coolDown?.cancel();
        coolDown = Timer(const Duration(milliseconds: 250), emitSnapshot);
      },
      onError: (e, st) {
        if (!closed) controller.addError(e, st);
      },
    );

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
          final resp = await _getWithFallback(
            '/fee_stats',
            timeout: const Duration(seconds: 6),
          );
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            base = int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
          }
        } catch (_) {}

        final ops = opCount <= 0 ? 1 : opCount;
        final perOp = (x * 1e7 / ops).round();
        final total = (x * 1e7).round();

        controller.add(FeeEstimate(
          perOpStroops: perOp,
          totalStroops: total,
          totalXlm: x,
          baseFee: base,
          opCount: ops,
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

    final ledSub = _sseWithFallback<void>(_ledgerStream).listen(
          (_) => push(DateTime.now()),
      onError: controller.addError,
      onDone: controller.close,
    );

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

  Stream<PairPrice> xlmUsdcPriceStream() {
    Stream<PairPrice> _build(StellarSDK s) {
      final tradesBuilder = s.trades;
      tradesBuilder.queryParameters['base_asset_type'] = 'native';
      tradesBuilder.queryParameters['counter_asset_type'] = 'credit_alphanum4';
      tradesBuilder.queryParameters['counter_asset_code'] = 'USDC';
      tradesBuilder.queryParameters['counter_asset_issuer'] = usdcIssuer;

      return tradesBuilder.cursor('now').stream().map((t) {
        double? price;
        final ba = double.tryParse('${t.baseAmount}');
        final ca = double.tryParse('${t.counterAmount}');

        if (ba != null && ba > 0 && ca != null && ca > 0) {
          price = ca / ba;
        }

        price ??= double.tryParse('${t.price}');

        if (price != null && price > 0) {
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
}