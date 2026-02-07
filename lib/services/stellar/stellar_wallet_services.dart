// StellarWalletServices.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/wallet_models.dart';
import 'package:next_fi/services/stellar/soroban_rpc.dart';
import 'package:next_fi/services/profit_address_vault_secure_storage.dart';

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
  // Mnemonic & Wallet Management (SDK v3 Wallet – SEP-0005)
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate a 12-word mnemonic using Stellar SDK.
  Future<String> generateMnemonic12() async {
    return await Wallet.generate12WordsMnemonic();
  }

  /// Generate a 24-word mnemonic using Stellar SDK.
  Future<String> generateMnemonic24() async {
    return await Wallet.generate24WordsMnemonic();
  }

  /// Generate a mnemonic with custom word count.
  Future<String> generateMnemonic({int wordCount = 12}) async {
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
    return await Wallet.from(mnemonic, passphrase: passphrase);
  }

  /// Get keypair at specific [index] from mnemonic.
  /// Uses Stellar derivation path: m/44'/148'/index'
  Future<KeyPair> getKeyPairFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
    return await wallet.getKeyPair(index: index);
  }

  /// Get account ID at specific [index] without full keypair.
  Future<String> getAccountIdFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
    return await wallet.getAccountId(index: index);
  }

  /// Derive multiple accounts from mnemonic.
  Future<List<KeyPair>> deriveAccounts(
      String mnemonic, {
        required int count,
        String passphrase = '',
      }) async {
    final wallet = await Wallet.from(mnemonic, passphrase: passphrase);
    final accounts = <KeyPair>[];

    for (int i = 0; i < count; i++) {
      accounts.add(await wallet.getKeyPair(index: i));
    }

    return accounts;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Secure Storage
  // ──────────────────────────────────────────────────────────────────────────

  /// Store mnemonic securely.
  Future<void> storeMnemonic(String mnemonic, {String key = 'stellar_mnemonic'}) async {
    await _secureStorage.write(key: key, value: mnemonic);
  }

  /// Retrieve stored mnemonic.
  Future<String?> retrieveMnemonic({String key = 'stellar_mnemonic'}) async {
    return await _secureStorage.read(key: key);
  }

  /// Delete stored mnemonic.
  Future<void> deleteMnemonic({String key = 'stellar_mnemonic'}) async {
    await _secureStorage.delete(key: key);
  }

  /// Store keypair secret seed securely.
  Future<void> storeSecretSeed(
      String secretSeed, {
        String key = 'stellar_secret',
      }) async {
    await _secureStorage.write(key: key, value: secretSeed);
  }

  /// Retrieve stored secret seed.
  Future<String?> retrieveSecretSeed({String key = 'stellar_secret'}) async {
    return await _secureStorage.read(key: key);
  }

  /// Create keypair from stored secret.
  Future<KeyPair?> getKeyPairFromStorage({String key = 'stellar_secret'}) async {
    final secret = await _secureStorage.read(key: key);
    if (secret == null) return null;
    return KeyPair.fromSecretSeed(secret);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Assets
  // ──────────────────────────────────────────────────────────────────────────
  Asset get _xlm => Asset.NATIVE;
  Asset get _usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  static const double _kTxFeeUsdc = 0.005;
  static String _fmt7(num v) => v.toStringAsFixed(7);
  static Never _fail(String message, [Object? inner]) =>
      throw Exception(inner == null ? message : '$message (inner: $inner)');

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
  Future<AccountResponse> _loadAccount(String accountId) =>
      sdk.accounts.account(accountId);

  bool get isTestnet => _isTestnet;

  Future<String> getTransactionFeeAddress() async {
    try {
      return (await configVault.readOrInit()).address;
    } catch (e) {
      _fail('Failed to get transaction fee address', e);
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
      _fail('Account address cannot be empty');
    }
    if (a.startsWith('G') && a.length >= 56) {
      return a;
    }
    if (a.startsWith('M')) {
      _fail('Muxed (M…) addresses are not supported here. Use classic G… + memo.');
    }
    _fail('Invalid account id: $a');
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
      _fail('Failed to fetch asset balance', e);
    }
  }

  /// Get all balances for an account.
  Future<List<Balance>> getAllBalances(String accountId) async {
    try {
      final acc = await _loadAccount(accountId);
      return acc.balances;
    } catch (e) {
      _fail('Failed to fetch balances', e);
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
      _fail('Failed to check USDC trustline', e);
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
      _fail('Failed to check trustline', e);
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
      if (!res.success) _failSubmit(res, prefix: 'ChangeTrust(USDC) failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create USDC trustline', e);
    }
  }

  Future<String> createTrustline({
    required KeyPair keyPair,
    required Asset asset,
    String limit = '922337203685.4775807',
  }) async {
    try {
      if (asset is AssetTypeNative) {
        _fail('Cannot create trustline for native XLM');
      }

      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'ChangeTrust failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create trustline', e);
    }
  }

  Future<String> removeTrustline({
    required KeyPair keyPair,
    required Asset asset,
  }) async {
    try {
      if (asset is AssetTypeNative) {
        _fail('Cannot remove trustline for native XLM');
      }

      final balance = await getAssetBalance(keyPair.accountId, asset);
      if (balance > 0) {
        _fail('Cannot remove trustline with non-zero balance: ${_fmt7(balance)}');
      }

      final acc = await _loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, '0').build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Remove trustline failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to remove trustline', e);
    }
  }

  Future<void> _ensureUsdcTrustlineSelf(
      KeyPair keyPair, {
        String limit = '922337203685.4775807',
      }) async {
    if (await hasUsdcTrustline(keyPair.accountId)) return;
    await createUsdcTrustline(keyPair: keyPair, limit: limit);
  }

  Future<void> _ensureTrustline(
      KeyPair keyPair,
      Asset asset, {
        String limit = '922337203685.4775807',
      }) async {
    if (await hasTrustline(keyPair.accountId, asset)) return;
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
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');
    if (claimants.isEmpty) _fail('Must have at least one claimant');

    try {
      if (asset is! AssetTypeNative) {
        await _ensureTrustline(keyPair, asset);
      }

      final balance = await getAssetBalance(keyPair.accountId, asset);
      if (balance < amount) {
        _fail('Insufficient balance. Have ${_fmt7(balance)} but need ${_fmt7(amount)}');
      }

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
      if (!res.success) _failSubmit(res, prefix: 'Create claimable balance failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create claimable balance', e);
    }
  }

  Future<String> claimClaimableBalance({
    required KeyPair keyPair,
    required String balanceId,
  }) async {
    try {
      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ClaimClaimableBalanceOperationBuilder(balanceId).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Claim claimable balance failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to claim claimable balance', e);
    }
  }

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
      _fail('Failed to get claimable balances', e);
    }
  }

  Future<String> createTimeLockedPayment({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
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
    );
  }

  Future<String> createUnconditionalClaimableBalance({
    required KeyPair keyPair,
    required Asset asset,
    required double amount,
    required String recipientId,
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
        _fail('Key must be 1-64 characters');
      }
      if (value.length > 64) {
        _fail('Value must be 0-64 characters');
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
      if (!res.success) _failSubmit(res, prefix: 'Set account data failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to set account data', e);
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
      if (!res.success) _failSubmit(res, prefix: 'Delete account data failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to delete account data', e);
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
      if (!res.success) _failSubmit(res, prefix: 'Set account options failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to set account options', e);
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
  }) async {
    try {
      final dest = _toClassicAccountId(destinationId);

      if (!await _accountExists(dest)) {
        _fail('Destination account does not exist');
      }

      final acc = await _loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        AccountMergeOperationBuilder(dest).build(),
      )
          .build();
      tx.sign(keyPair, _network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'Account merge failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to merge account', e);
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
      if (!res.success) _failSubmit(res, prefix: 'Sponsorship failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to sponsor account', e);
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
  }) async {
    try {
      await _ensureTrustline(keyPair, selling);
      await _ensureTrustline(keyPair, buying);

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
      if (!res.success) _failSubmit(res, prefix: 'Create sell offer failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create sell offer', e);
    }
  }

  Future<String> createBuyOffer({
    required KeyPair keyPair,
    required Asset buying,
    required Asset selling,
    required double amount,
    required double price,
    int? offerId,
  }) async {
    try {
      await _ensureTrustline(keyPair, selling);
      await _ensureTrustline(keyPair, buying);

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
      if (!res.success) _failSubmit(res, prefix: 'Create buy offer failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to create buy offer', e);
    }
  }

  Future<String> cancelOffer({
    required KeyPair keyPair,
    required int offerId,
    required Asset selling,
    required Asset buying,
  }) async {
    try {
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
      if (!res.success) _failSubmit(res, prefix: 'Cancel offer failed');
      return res.hash!;
    } catch (e) {
      _fail('Failed to cancel offer', e);
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
      _fail('Failed to get account offers', e);
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
      _fail('Failed to get order book', e);
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
  }) async {
    if (amount <= 0) _fail('Amount must be > 0');

    final dest = _toClassicAccountId(destination);
    final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);
    final totalStroops = _toStroops(amount);

    if (totalStroops <= feeStroops) {
      _fail('Amount too small: must be greater than transaction fee of ${_fmt7(feeXlm)} XLM');
    }

    final recvXlm = _fromStroops(totalStroops - feeStroops);
    final acc = await _loadAccount(keyPair.accountId);

    final needsFeeOp = feeStroops > 0;
    final opCount = needsFeeOp ? 2 : 1;
    final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
    final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

    final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

    final destExists = await _accountExists(dest);
    if (destExists) {
      tb.addOperation(
        PaymentOperationBuilder(dest, _xlm, _fmt7(recvXlm)).build(),
      );
    } else {
      if (recvXlm < 1.0) {
        _fail('Destination account does not exist. Minimum 1 XLM required to create account, but only ${_fmt7(recvXlm)} XLM after fees.');
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

    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'XLM send failed');
      return [res.hash!];
    } catch (e) {
      if (_sdkQuickNode != null) {
        try {
          final res = await _sdkQuickNode!.submitTransaction(tx);
          if (!res.success) _failSubmit(res, prefix: 'XLM send failed (fallback)');
          return [res.hash!];
        } catch (_) {
          _fail('XLM send failed', e);
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
  }) async {
    if (usdcAmount <= 0) _fail('usdcAmount must be > 0');

    final dest = _toClassicAccountId(destination);
    final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());

    if (!await _accountExists(dest)) {
      _fail('Destination account does not exist. Ask recipient to create/fund a Stellar account first.');
    }

    await _ensureUsdcTrustlineSelf(keyPair);

    if (!await hasUsdcTrustline(dest)) {
      _fail('Destination has no USDC trustline. Ask recipient to add USDC first.');
    }

    final feeStroops = await getCurrentFeeStroops();
    final feeXlm = _fromStroops(feeStroops);

    final senderXlmBal = await getXlmBalance(keyPair.accountId);
    if (senderXlmBal < feeXlm) {
      _fail('Insufficient XLM to pay the transaction fee of ${_fmt7(feeXlm)} XLM.');
    }

    final senderUsdcBal = await getUsdcBalance(keyPair.accountId);
    if (senderUsdcBal < usdcAmount) {
      _fail('Insufficient USDC balance. Have ${_fmt7(senderUsdcBal)} but need ${_fmt7(usdcAmount)}.');
    }

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

    try {
      final res = await sdk.submitTransaction(tx);
      if (!res.success) _failSubmit(res, prefix: 'USDC payment failed');
      return [res.hash!];
    } catch (e) {
      if (_sdkQuickNode != null) {
        try {
          final res = await _sdkQuickNode!.submitTransaction(tx);
          if (!res.success) _failSubmit(res, prefix: 'USDC payment failed (fallback)');
          return [res.hash!];
        } catch (_) {
          _fail('USDC payment failed', e);
        }
      }
      rethrow;
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
  }) async {
    if (sendAmountXlm <= 0) _fail('sendAmountXlm must be > 0');
    if (minUsdcOut <= 0) _fail('minUsdcOut must be > 0');

    try {
      final self = keyPair.accountId;
      final dest = (destination?.trim().isNotEmpty == true)
          ? _toClassicAccountId(destination!.trim())
          : self;

      await _ensureUsdcTrustlineSelf(keyPair);

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

      const minReserve = 1.5;
      final totalNeeded = sendAmountXlm + feeXlm + minReserve;

      if (senderXlmBal < totalNeeded) {
        _fail(
          'Insufficient XLM. Need ${_fmt7(totalNeeded)} (${_fmt7(sendAmountXlm)} to swap + ${_fmt7(feeXlm)} fee + ${_fmt7(minReserve)} reserve), but have ${_fmt7(senderXlmBal)}.',
        );
      }

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

      final senderUsdcBal = await getUsdcBalance(self);
      if (senderUsdcBal < sendAmountUsdc) {
        _fail('Insufficient USDC balance. Have ${_fmt7(senderUsdcBal)} but need ${_fmt7(sendAmountUsdc)}.');
      }

      final feeAddr = _toClassicAccountId(await getTransactionFeeAddress());
      final feeStroops = await getCurrentFeeStroops();
      final feeXlm = _fromStroops(feeStroops);

      final acc = await _loadAccount(self);

      final needsFeeOp = feeStroops > 0;
      final opCount = needsFeeOp ? 2 : 1;
      final feeXlmNet = await estimateNetworkFeeXlm(opCount: opCount, percentile: 90);
      final perOpStroops = (feeXlmNet * 1e7 / opCount).ceil();

      final tb = TransactionBuilder(acc)..setMaxOperationFee(perOpStroops);

      if (dest == self) {
        if (minXlmOut < feeXlm) {
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
        final senderXlmBal = await getXlmBalance(self);
        if (senderXlmBal < feeXlm) {
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

      if (memoText?.isNotEmpty == true) {
        tb.addMemo(Memo.text(memoText!));
      }

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

  // ──────────────────────────────────────────────────────────────────────────
  // Error helpers
  // ──────────────────────────────────────────────────────────────────────────
  Never _failSubmit(
      SubmitTransactionResponse res, {
        String prefix = 'Transaction failed',
      }) {
    final code = res.extras?.resultCodes?.transactionResultCode ?? 'tx_failed';
    final ops = res.extras?.resultCodes?.operationsResultCodes?.join(', ');
    final hash = res.hash;
    final msg = '$prefix ($code${ops != null ? '; ops: $ops' : ''}${hash != null ? '; hash: $hash' : ''})';
    _fail(msg);
  }
}