// stellar_account_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/stellar/stellar_base_service.dart';

/// Service for account management, balances, trustlines, and account options
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Reserve Calculation (Stellar Protocol)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Network base reserve reference used for local reserve math.
  /// Fallback value: 0.5 XLM base reserve => 1.0 XLM minimum account reserve.
  static const double _baseReserve = 0.5;

  /// Each subentry (trustline/offer/signer/data) adds one base reserve.
  static const double _subentryReserve = _baseReserve;

  /// Minimum account balance = (2 + numSubEntries) * baseReserve
  /// Includes sponsorship deltas:
  /// (2 + numSubEntries + numSponsoring - numSponsored) * baseReserve.
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

  /// Calculate spendable XLM balance (total - minimum reserve - selling liabilities)
  double _calculateSpendableXlm(
    AccountResponse account, {
    double? baseReserve,
    double? subentryReserve,
  }) {
    // Get total XLM balance
    double totalXlm = 0.0;
    double sellingLiabilities = 0.0;

    for (final balance in account.balances) {
      if (balance.assetType == Asset.TYPE_NATIVE) {
        totalXlm = double.tryParse(balance.balance) ?? 0.0;

        // Selling liabilities are XLM locked in sell offers
        sellingLiabilities =
            double.tryParse(balance.sellingLiabilities ?? '0') ?? 0.0;
        break;
      }
    }

    // Calculate minimum balance required
    final minimumBalance = _calculateMinimumBalance(
      account,
      baseReserve: baseReserve,
      subentryReserve: subentryReserve,
    );

    // Use integer stroops math to avoid floating drift near reserve boundaries.
    final totalStroops = toStroops(totalXlm);
    final reserveStroops = (minimumBalance * 1e7).ceil();
    final liabilitiesStroops = toStroops(sellingLiabilities);
    final spendableStroops = totalStroops - reserveStroops - liabilitiesStroops;

    // Return 0 if negative (shouldn't happen in normal circumstances)
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Balances
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Get spendable XLM balance (excludes minimum reserve and selling liabilities)
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

  /// Returns the latest minimum XLM needed to activate a brand-new account.
  /// Pulls latest ledger reserve data from Horizon and falls back safely.
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
          // Minimum account reserve is currently 2 * base reserve.
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

  /// Get total XLM balance (includes reserves - use for display purposes only)
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

  /// Get XLM minimum balance (base reserve + subentry reserves)
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

  /// Get available (spendable) balance for an asset
  /// For XLM: Returns spendable amount (total - reserves - selling liabilities)
  /// For other assets: Returns available amount (balance - selling liabilities)
  Future<double> getUsdcBalance(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      for (final b in acc.balances) {
        if (b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer) {
          return _availableCreditBalance(b);
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

  /// Get available (spendable) balance for any asset
  /// For XLM: Returns spendable amount (total - reserves - selling liabilities)
  /// For other assets: Returns available amount (balance - selling liabilities)
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

  /// Get detailed balance breakdown for an account
  /// Returns map with total, spendable, reserved, and locked amounts
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Trustlines
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<bool> hasUsdcTrustline(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      return acc.balances.any(
        (b) => b.assetCode == 'USDC' && b.assetIssuer == usdcIssuer,
      );
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
          technicalError:
              'Current balance: ${StellarBaseService.fmt7(balance)}',
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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Account Data
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Account Options
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Account Merge
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Sponsorship
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // Add these new methods to your StellarAccountService class
  // Insert them after the getXlmMinimumBalance method

  /// Get the base reserve amount (2 * baseReserve)
  /// This is the minimum balance required for an account with no subentries
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

  /// Get the trustline reserve amount (number of trustlines * subentryReserve)
  /// This is the reserve locked up by trustlines only
  Future<double> getTrustlineReserve(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final subentryReserve = await _resolveBaseReserveOrFallback();

      // Count trustlines (non-native balances)
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

  /// Get the total subentry reserve (all subentries * subentryReserve)
  /// Includes trustlines, signers, data entries, and offers
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

  /// Get detailed reserve breakdown
  /// Returns map with base, trustline, and other subentry reserves
  Future<Map<String, double>> getReserveBreakdown(String accountId) async {
    try {
      final acc = await loadAccount(accountId);
      final subentryReserve = await _resolveBaseReserveOrFallback();

      // Count each type of subentry
      int trustlineCount = acc.balances
          .where((b) => b.assetType != Asset.TYPE_NATIVE)
          .length;

      int signerCount = acc.signers.where((s) => s.key != acc.accountId).length;

      int dataEntryCount = acc.data.length;

      // Total subentries (may include offers not directly visible)
      final totalSubentries = acc.subentryCount;
      final numSponsoring = acc.numSponsoring;
      final numSponsored = acc.numSponsored;
      final effectiveSubentries =
          (totalSubentries + numSponsoring - numSponsored).clamp(0, 1 << 30);

      // Calculate reserves
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
