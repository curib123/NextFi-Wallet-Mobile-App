// stellar_account_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';

/// Service for account management, balances, trustlines, and account options
class StellarAccountService extends StellarBaseService {
  final String usdcIssuer;

  StellarAccountService({
    required this.usdcIssuer,
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  }) : super(
    sdk: sdk,
    sdkQuickNode: sdkQuickNode,
    quickNodeUrlMainnet: quickNodeUrlMainnet,
    quickNodeUrlTestnet: quickNodeUrlTestnet,
    quickNodeDefaultHeaders: quickNodeDefaultHeaders,
  );

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  // ──────────────────────────────────────────────────────────────────────────
  // Balances
  // ──────────────────────────────────────────────────────────────────────────

  Future<double> getXlmBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) return double.parse(b.balance);
      }
      return 0.0;
    } catch (e) {
      fail(
        'Unable to fetch XLM balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getUsdcBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer) {
          return double.parse(b.balance);
        }
      }
      return 0.0;
    } catch (e) {
      fail(
        'Unable to fetch USDC balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getAssetBalance(String accountId, Asset asset) async {
    try {
      final acc = await loadAccount(accountId);

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
      fail(
        'Unable to fetch balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<List<Balance>> getAllBalances(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      return acc.balances;
    } catch (e) {
      fail(
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
      final acc = await loadAccount(accountId);
      return acc.balances
          .any((b) => b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer);
    } catch (e) {
      fail(
        'Unable to check USDC status',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<bool> hasTrustline(String accountId, Asset asset) async {
    try {
      if (asset is AssetTypeNative) return true;

      final acc = await loadAccount(accountId);
      if (asset is AssetTypeCreditAlphaNum) {
        return acc.balances.any(
              (b) => b.assetCode == asset.code && b.assetIssuer == asset.issuerId,
        );
      }
      return false;
    } catch (e) {
      fail(
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
      final acc = await loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(usdc, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to add USDC');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
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
        fail(
          'XLM is already in your wallet',
          advice:
          'You don\'t need to add XLM - it\'s the native Stellar currency',
          code: 'NATIVE_ASSET',
        );
      }

      final acc = await loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, limit).build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to add asset');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
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
        fail(
          'XLM cannot be removed',
          advice:
          'XLM is the native Stellar currency and is always in your wallet',
          code: 'NATIVE_ASSET',
        );
      }

      final balance = await getAssetBalance(keyPair.accountId, asset);
      if (balance > 0) {
        fail(
          'Can\'t remove this asset yet',
          technicalError: 'Current balance: ${StellarBaseService.fmt7(balance)}',
          advice:
          'You need to send or swap all your funds before removing this asset from your wallet',
          code: 'NON_ZERO_BALANCE',
        );
      }

      final acc = await loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, '0').build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to remove asset');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to remove asset from your wallet',
        technicalError: e,
        advice:
        'Please try again. If the problem persists, check your internet connection',
      );
    }
  }

  Future<void> ensureUsdcTrustline(
      KeyPair keyPair, {
        String limit = '922337203685.4775807',
        ProgressCallback? onProgress,
      }) async {
    if (await hasUsdcTrustline(keyPair.accountId)) return;
    onProgress?.call('Setting up USDC in your wallet...');
    await createUsdcTrustline(keyPair: keyPair, limit: limit);
  }

  Future<void> ensureTrustline(
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
  // Account Data
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> setAccountData({
    required KeyPair keyPair,
    required String key,
    required String value,
  }) async {
    try {
      if (key.isEmpty || key.length > 64) {
        fail(
          'Data key is ${key.isEmpty ? "empty" : "too long"}',
          technicalError: 'Length: ${key.length} characters (max: 64)',
          advice: 'Please use a key between 1 and 64 characters',
          code: 'INVALID_KEY_LENGTH',
        );
      }
      if (value.length > 64) {
        fail(
          'Data value is too long',
          technicalError: 'Length: ${value.length} characters (max: 64)',
          advice: 'Please shorten your data to 64 characters or less',
          code: 'INVALID_VALUE_LENGTH',
        );
      }

      final Uint8List valueBytes = Uint8List.fromList(utf8.encode(value));
      final acc = await loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ManageDataOperationBuilder(key, valueBytes).build(),
      )
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to save data');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
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
      final acc = await loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        ManageDataOperationBuilder(key, null).build(),
      )
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to delete data');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
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
      final acc = await loadAccount(accountId);
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
      final acc = await loadAccount(keyPair.accountId);

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
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success)
        failSubmit(res, prefix: 'Unable to update account settings');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
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
      final dest = toClassicAccountId(destinationId);

      onProgress?.call('Checking destination account...');
      if (!await accountExists(dest)) {
        fail(
          'Destination account doesn\'t exist',
          technicalError: 'Account not found: $dest',
          advice:
          'The destination account needs to be active on the Stellar network before you can merge',
          code: 'DESTINATION_NOT_FOUND',
        );
      }

      onProgress?.call('Merging accounts...');
      final acc = await loadAccount(keyPair.accountId);

      final tx = TransactionBuilder(acc)
          .setMaxOperationFee(100)
          .addOperation(
        AccountMergeOperationBuilder(dest).build(),
      )
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to merge accounts');

      onProgress?.call('Accounts merged successfully!');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to merge accounts',
        technicalError: e,
        advice:
        'Make sure you have no active trustlines, offers, or data entries before merging',
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
      final sponsored = toClassicAccountId(sponsoredId);
      final acc = await loadAccount(sponsorKeyPair.accountId);

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
      tx.sign(sponsorKeyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) failSubmit(res, prefix: 'Unable to sponsor account');
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to sponsor account',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }
}