import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';

class TrustlineRemovalCheck {
  const TrustlineRemovalCheck({
    required this.hasTrustline,
    required this.balance,
    required this.availableBalance,
    required this.sellingLiabilities,
    required this.canRemove,
    this.blockingReason,
  });

  final bool hasTrustline;
  final double balance;
  final double availableBalance;
  final double sellingLiabilities;
  final bool canRemove;
  final String? blockingReason;
}

class StellarAccountService extends StellarBaseService {
  final String usdcIssuer;
  static const double fallbackAccountActivationMinXlm = 1.0;
  static const Duration _activationMinCacheTtl = Duration(minutes: 10);
  double? _cachedActivationMinXlm;
  DateTime? _cachedActivationMinAt;

  StellarAccountService({
    required this.usdcIssuer,
    required super.sdk,
    super.sdkQuickNode,
    super.quickNodeUrlMainnet,
    super.quickNodeUrlTestnet,
    super.quickNodeDefaultHeaders,
  });

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  String _assetLabel(Asset asset) {
    if (asset is AssetTypeNative) return 'XLM';
    if (asset is AssetTypeCreditAlphaNum) return asset.code;
    return 'asset';
  }

  static const double _baseReserve = 0.5;

  static const double _subentryReserve = _baseReserve;

  double _calculateMinimumBalance(
    AccountResponse account, {
    double? baseReserve,
    double? subentryReserve,
  }) {
    final base = baseReserve ?? _baseReserve;
    final subentry = subentryReserve ?? _subentryReserve;
    final numSubentries = account.subentryCount;

    final numSponsoring = account.numSponsoring;
    final numSponsored = account.numSponsored;
    final effectiveSubentries = (numSubentries + numSponsoring - numSponsored)
        .clamp(0, 1 << 30);

    final minimumBalance = (2 * base) + (effectiveSubentries * subentry);

    return minimumBalance;
  }

  double _calculateSpendableXlm(
    AccountResponse account, {
    double? baseReserve,
    double? subentryReserve,
  }) {
    double totalXlm = 0.0;
    double sellingLiabilities = 0.0;

    for (final balance in account.balances) {
      if (balance.assetType == Asset.TYPE_NATIVE) {
        totalXlm = double.tryParse(balance.balance) ?? 0.0;

        sellingLiabilities =
            double.tryParse(balance.sellingLiabilities ?? '0') ?? 0.0;
        break;
      }
    }

    final minimumBalance = _calculateMinimumBalance(
      account,
      baseReserve: baseReserve,
      subentryReserve: subentryReserve,
    );

    final totalStroops = toStroops(totalXlm);
    final reserveStroops = (minimumBalance * 1e7).ceil();
    final liabilitiesStroops = toStroops(sellingLiabilities);
    final spendableStroops = totalStroops - reserveStroops - liabilitiesStroops;

    return spendableStroops > 0 ? fromStroops(spendableStroops) : 0.0;
  }

  double _parseAmount(String raw) => double.tryParse(raw.trim()) ?? 0.0;

  double _availableCreditBalance(Balance b) {
    final balance = _parseAmount(b.balance);
    final sellingLiabilities = _parseAmount(b.sellingLiabilities ?? '0');
    final available = balance - sellingLiabilities;
    return available > 0 ? available : 0.0;
  }

  Future<double> _resolveBaseReserveOrFallback() async {
    try {
      final minActivation = await getLatestAccountActivationMinXlm();
      if (minActivation > 0) return minActivation / 2.0;
    } catch (_) {
      final cachedMin = _cachedActivationMinXlm;
      if (cachedMin != null && cachedMin > 0) return cachedMin / 2.0;
    }
    return _baseReserve;
  }

  Future<double> getXlmBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final baseReserve = await _resolveBaseReserveOrFallback();
      return _calculateSpendableXlm(
        acc,
        baseReserve: baseReserve,
        subentryReserve: baseReserve,
      );
    } catch (e) {
      fail(
        'Unable to fetch XLM balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getLatestAccountActivationMinXlm({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedActivationMinXlm != null &&
        _cachedActivationMinAt != null &&
        now.difference(_cachedActivationMinAt!) < _activationMinCacheTtl) {
      return _cachedActivationMinXlm!;
    }

    try {
      final resp = await getWithFallback(
        '/ledgers',
        query: const {'order': 'desc', 'limit': '1'},
        timeout: const Duration(seconds: 10),
      );
      if (resp.statusCode != 200) {
        fail(
          'Unable to get latest base reserve.',
          technicalError: 'Horizon status ${resp.statusCode}',
          advice: 'Please try again in a moment.',
          code: 'BASE_RESERVE_FETCH_FAILED',
        );
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final records = (data['_embedded']?['records'] as List?) ?? const [];
      if (records.isEmpty || records.first is! Map) {
        fail(
          'Unable to get latest base reserve.',
          technicalError: 'Ledger response has no records',
          advice: 'Please try again in a moment.',
          code: 'BASE_RESERVE_MISSING',
        );
      }

      final row = records.first as Map;
      final stroopsRaw = row['base_reserve_in_stroops'];
      double? minXlm;
      if (stroopsRaw != null) {
        final reserveStroops = int.tryParse('$stroopsRaw');
        if (reserveStroops != null && reserveStroops > 0) {
          minXlm = (reserveStroops * 2) / 10000000.0;
        }
      }

      final baseReserveRaw = row['base_reserve'];
      if ((minXlm == null || minXlm <= 0) && baseReserveRaw != null) {
        final baseReserve = double.tryParse('$baseReserveRaw');
        if (baseReserve != null && baseReserve > 0) {
          minXlm = baseReserve * 2;
        }
      }

      if (minXlm == null || minXlm <= 0) {
        fail(
          'Unable to get latest base reserve.',
          technicalError: 'No valid base reserve in latest ledger',
          advice: 'Please try again in a moment.',
          code: 'BASE_RESERVE_INVALID',
        );
      }

      final normalized = ((minXlm * 10000000).ceil()) / 10000000.0;
      _cachedActivationMinXlm = normalized;
      _cachedActivationMinAt = now;
      return normalized;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to get latest base reserve.',
        technicalError: e,
        advice: 'Please check your internet connection and try again.',
        code: 'BASE_RESERVE_FETCH_FAILED',
      );
    }
  }

  Future<double> getTotalXlmBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) return _parseAmount(b.balance);
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

  Future<double> getXlmMinimumBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final baseReserve = await _resolveBaseReserveOrFallback();
      return _calculateMinimumBalance(
        acc,
        baseReserve: baseReserve,
        subentryReserve: baseReserve,
      );
    } catch (e) {
      fail(
        'Unable to fetch minimum balance',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getUsdcBalance(String accountId) =>
      getAssetBalance(accountId, usdc);

  Future<double> getAssetBalance(String accountId, Asset asset) async {
    try {
      final acc = await loadAccount(accountId);

      if (asset is AssetTypeNative) {
        final baseReserve = await _resolveBaseReserveOrFallback();
        return _calculateSpendableXlm(
          acc,
          baseReserve: baseReserve,
          subentryReserve: baseReserve,
        );
      }

      if (asset is AssetTypeCreditAlphaNum) {
        for (final b in acc.balances) {
          if (b.assetCode == asset.code && b.assetIssuer == asset.issuerId) {
            return _availableCreditBalance(b);
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

  Future<Map<String, double>> getXlmBalanceBreakdown(String accountId) async {
    try {
      final acc = await loadAccount(accountId);

      double totalXlm = 0.0;
      double sellingLiabilities = 0.0;

      for (final b in acc.balances) {
        if (b.assetType == Asset.TYPE_NATIVE) {
          totalXlm = _parseAmount(b.balance);
          sellingLiabilities = _parseAmount(b.sellingLiabilities ?? '0');
          break;
        }
      }

      final baseReserve = await _resolveBaseReserveOrFallback();
      final minimumBalance = _calculateMinimumBalance(
        acc,
        baseReserve: baseReserve,
        subentryReserve: baseReserve,
      );
      final spendable = _calculateSpendableXlm(
        acc,
        baseReserve: baseReserve,
        subentryReserve: baseReserve,
      );
      final effectiveSubentries =
          (acc.subentryCount + acc.numSponsoring - acc.numSponsored).clamp(
            0,
            1 << 30,
          );

      return {
        'total': totalXlm,
        'spendable': spendable > 0 ? spendable : 0.0,
        'reserved': minimumBalance,
        'locked': sellingLiabilities,
        'baseReserve': baseReserve,
        'subentries': acc.subentryCount.toDouble(),
        'numSponsoring': acc.numSponsoring.toDouble(),
        'numSponsored': acc.numSponsored.toDouble(),
        'effectiveSubentries': effectiveSubentries.toDouble(),
      };
    } catch (e) {
      fail(
        'Unable to fetch balance breakdown',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<bool> hasUsdcTrustline(String accountId) =>
      hasTrustline(accountId, usdc);

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
  }) => createTrustline(keyPair: keyPair, asset: usdc, limit: limit);

  Future<String> createTrustline({
    required KeyPair keyPair,
    required Asset asset,
    String limit = '922337203685.4775807',
  }) async {
    try {
      if (asset is AssetTypeNative) {
        fail(
          '${_assetLabel(asset)} is already in your wallet',
          advice:
              'You don\'t need to add ${_assetLabel(asset)} - it\'s the native Stellar currency',
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
      if (!res.success) {
        failSubmit(res, prefix: 'Unable to add ${_assetLabel(asset)}');
      }
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to add ${_assetLabel(asset)} to your wallet',
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
          '${_assetLabel(asset)} cannot be removed',
          advice:
              '${_assetLabel(asset)} is the native Stellar currency and is always in your wallet',
          code: 'NATIVE_ASSET',
        );
      }

      final eligibility = await getTrustlineRemovalCheck(
        accountId: keyPair.accountId,
        asset: asset,
      );
      if (!eligibility.canRemove) {
        fail(
          'Can\'t remove this asset yet',
          technicalError:
              'Balance: ${StellarBaseService.fmt7(eligibility.balance)} | '
              'Available: ${StellarBaseService.fmt7(eligibility.availableBalance)} | '
              'Selling liabilities: ${StellarBaseService.fmt7(eligibility.sellingLiabilities)}',
          advice:
              eligibility.blockingReason ??
              'You need to clear the balance and any in-flight obligations before removing this trustline.',
          code: 'TRUSTLINE_NOT_REMOVABLE',
        );
      }

      final acc = await loadAccount(keyPair.accountId);
      final tx = TransactionBuilder(acc)
          .addOperation(ChangeTrustOperationBuilder(asset, '0').build())
          .setMaxOperationFee(100)
          .build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) {
        failSubmit(res, prefix: 'Unable to remove ${_assetLabel(asset)}');
      }
      return res.hash!;
    } catch (e) {
      if (e is StellarWalletError) rethrow;
      fail(
        'Unable to remove ${_assetLabel(asset)} from your wallet',
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
  }) => ensureTrustline(keyPair, usdc, limit: limit, onProgress: onProgress);

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

  Future<TrustlineRemovalCheck> getTrustlineRemovalCheck({
    required String accountId,
    required Asset asset,
  }) async {
    if (asset is AssetTypeNative) {
      return const TrustlineRemovalCheck(
        hasTrustline: false,
        balance: 0.0,
        availableBalance: 0.0,
        sellingLiabilities: 0.0,
        canRemove: false,
        blockingReason:
            'XLM is the native Stellar asset and cannot be removed.',
      );
    }

    final acc = await loadAccount(accountId);
    if (asset is! AssetTypeCreditAlphaNum) {
      return const TrustlineRemovalCheck(
        hasTrustline: false,
        balance: 0.0,
        availableBalance: 0.0,
        sellingLiabilities: 0.0,
        canRemove: false,
        blockingReason: 'Unsupported asset type for trustline removal.',
      );
    }

    final match = acc.balances
        .where((balance) {
          return balance.assetCode == asset.code &&
              balance.assetIssuer == asset.issuerId;
        })
        .cast<Balance?>()
        .firstWhere((balance) => balance != null, orElse: () => null);

    if (match == null) {
      return const TrustlineRemovalCheck(
        hasTrustline: false,
        balance: 0.0,
        availableBalance: 0.0,
        sellingLiabilities: 0.0,
        canRemove: false,
        blockingReason: 'No active trustline was found for this asset.',
      );
    }

    final balance = _parseAmount(match.balance);
    final sellingLiabilities = _parseAmount(match.sellingLiabilities ?? '0');
    final availableBalance = _availableCreditBalance(match);
    final canRemove =
        balance <= 0.0000001 &&
        availableBalance <= 0.0000001 &&
        sellingLiabilities <= 0.0000001;

    String? reason;
    if (balance > 0.0000001) {
      reason =
          'Send, swap, or claim out the remaining ${_assetLabel(asset)} balance before removing the trustline.';
    } else if (sellingLiabilities > 0.0000001) {
      reason =
          'This trustline still has open liabilities or pending market obligations. Wait for them to clear before removing it.';
    }

    return TrustlineRemovalCheck(
      hasTrustline: true,
      balance: balance,
      availableBalance: availableBalance,
      sellingLiabilities: sellingLiabilities,
      canRemove: canRemove,
      blockingReason: reason,
    );
  }

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
          .addOperation(ManageDataOperationBuilder(key, valueBytes).build())
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
          .addOperation(ManageDataOperationBuilder(key, null).build())
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
      final dataValue = acc.data[key];

      final decoded = base64.decode(dataValue);
      return utf8.decode(decoded);
    } catch (e) {
      return null;
    }
  }

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

      final tx = TransactionBuilder(
        acc,
      ).setMaxOperationFee(100).addOperation(builder.build()).build();
      tx.sign(keyPair, network);

      final res = await sdk.submitTransaction(tx);
      if (!res.success) {
        failSubmit(res, prefix: 'Unable to update account settings');
      }
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
    return setAccountOptions(keyPair: keyPair, homeDomain: domain);
  }

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
          .addOperation(AccountMergeOperationBuilder(dest).build())
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

  Future<double> getBaseReserve(String accountId) async {
    try {
      final baseReserve = await _resolveBaseReserveOrFallback();
      return 2 * baseReserve;
    } catch (e) {
      fail(
        'Unable to fetch base reserve',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getTrustlineReserve(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final subentryReserve = await _resolveBaseReserveOrFallback();

      int trustlineCount = acc.balances
          .where((b) => b.assetType != Asset.TYPE_NATIVE)
          .length;

      return trustlineCount * subentryReserve;
    } catch (e) {
      fail(
        'Unable to fetch trustline reserve',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<double> getSubentryReserve(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final subentryReserve = await _resolveBaseReserveOrFallback();

      final numSubentries = acc.subentryCount;

      return numSubentries * subentryReserve;
    } catch (e) {
      fail(
        'Unable to fetch subentry reserve',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }

  Future<Map<String, double>> getReserveBreakdown(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final subentryReserve = await _resolveBaseReserveOrFallback();

      int trustlineCount = acc.balances
          .where((b) => b.assetType != Asset.TYPE_NATIVE)
          .length;

      int signerCount = acc.signers.where((s) => s.key != acc.accountId).length;

      int dataEntryCount = acc.data.length;

      final totalSubentries = acc.subentryCount;
      final numSponsoring = acc.numSponsoring;
      final numSponsored = acc.numSponsored;
      final effectiveSubentries =
          (totalSubentries + numSponsoring - numSponsored).clamp(0, 1 << 30);

      final baseReserve = 2 * subentryReserve;
      final trustlineReserve = trustlineCount * subentryReserve;
      final signerReserve = signerCount * subentryReserve;
      final dataReserve = dataEntryCount * subentryReserve;
      final sponsoringReserve = numSponsoring * subentryReserve;
      final sponsoredOffsetReserve = numSponsored * subentryReserve;
      final totalSubentryReserve = effectiveSubentries * subentryReserve;
      final totalMinimumBalance = baseReserve + totalSubentryReserve;

      return {
        'baseReserve': baseReserve,
        'trustlineReserve': trustlineReserve,
        'signerReserve': signerReserve,
        'dataReserve': dataReserve,
        'sponsoringReserve': sponsoringReserve,
        'sponsoredOffsetReserve': sponsoredOffsetReserve,
        'otherReserve':
            totalSubentryReserve -
            trustlineReserve -
            signerReserve -
            dataReserve,
        'totalSubentryReserve': totalSubentryReserve,
        'totalMinimumBalance': totalMinimumBalance,
        'trustlineCount': trustlineCount.toDouble(),
        'signerCount': signerCount.toDouble(),
        'dataEntryCount': dataEntryCount.toDouble(),
        'totalSubentries': totalSubentries.toDouble(),
        'numSponsoring': numSponsoring.toDouble(),
        'numSponsored': numSponsored.toDouble(),
        'effectiveSubentries': effectiveSubentries.toDouble(),
      };
    } catch (e) {
      fail(
        'Unable to fetch reserve breakdown',
        technicalError: e,
        advice: 'Please check your internet connection and try again',
      );
    }
  }
}
