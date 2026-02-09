// stellar_fee_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:next_fi/services/secure_storage/profit_address_vault_secure_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';

/// Service for fee estimation and price quotes
class StellarFeeService extends StellarBaseService {
  final String usdcIssuer;
  final TransactionFeeVaultSecureStorage configVault;

  StellarFeeService({
    required this.usdcIssuer,
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    TransactionFeeVaultSecureStorage? configVault,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  })  : configVault = configVault ?? TransactionFeeVaultSecureStorage(),
        super(
        sdk: sdk,
        sdkQuickNode: sdkQuickNode,
        quickNodeUrlMainnet: quickNodeUrlMainnet,
        quickNodeUrlTestnet: quickNodeUrlTestnet,
        quickNodeDefaultHeaders: quickNodeDefaultHeaders,
      );

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  static const double kTxFeeUsdc = 0.005;

  // ──────────────────────────────────────────────────────────────────────────
  // Fee Address
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> getTransactionFeeAddress() async {
    try {
      return (await configVault.readOrInit()).address;
    } catch (e) {
      fail(
        'Unable to load fee settings',
        technicalError: e,
        advice:
        'Please restart the app. If the problem continues, you may need to reinstall',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Fee Calculation
  // ──────────────────────────────────────────────────────────────────────────

  Future<double> computeDynamicFeeXlm() async {
    try {
      final x1 = await quoteUsdcToXlm(kTxFeeUsdc);
      if (x1 != null && x1 > 0) return x1;
    } catch (_) {}

    try {
      final usdcPer1Xlm = await quoteXlmToUsdc(1.0);
      if (usdcPer1Xlm != null && usdcPer1Xlm > 0) {
        final x2 = kTxFeeUsdc / usdcPer1Xlm;
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
    final xlm = await computeDynamicFeeXlm();
    return (xlm * 1e7).ceil();
  }

  Future<double> getCurrentFeeXlm() async =>
      fromStroops(await getCurrentFeeStroops());

  Future<String> getCurrentFeeLabel() async =>
      '${(await getCurrentFeeXlm()).toStringAsFixed(7)} XLM';

  // ──────────────────────────────────────────────────────────────────────────
  // Network Fee Estimation
  // ──────────────────────────────────────────────────────────────────────────

  Future<double> estimateNetworkFeeXlm({
    int opCount = 1,
    int percentile = 90,
  }) async {
    final ops = opCount <= 0 ? 1 : opCount;
    try {
      final resp = await getWithFallback(
        '/fee_stats',
        timeout: const Duration(seconds: 10),
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;

        final base =
            int.tryParse('${data['last_ledger_base_fee'] ?? '100'}') ?? 100;
        final fc = (data['fee_charged'] as Map?) ?? const {};
        final p = percentile.clamp(10, 99);
        final perTxStroops =
            int.tryParse('${fc['p$p'] ?? fc['p50'] ?? base}') ?? base;

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
  // Quotes
  // ──────────────────────────────────────────────────────────────────────────

  Future<double?> quoteStrictSend({
    required Asset sourceAsset,
    required String sourceAmount,
    required List<Asset> destinationAssets,
  }) async {
    String destAssetToQuery(Asset a) {
      if (a is AssetTypeNative) return 'native';
      if (a is AssetTypeCreditAlphaNum) return '${a.code}:${a.issuerId}';
      return 'native';
    }

    final destParam = destinationAssets.map(destAssetToQuery).join(',');

    final qp = <String, String>{
      'source_amount': sourceAmount,
      if (sourceAsset is AssetTypeNative) 'source_asset_type': 'native',
      if (sourceAsset is AssetTypeCreditAlphaNum) ...{
        'source_asset_type': 'credit_alphanum${sourceAsset.code.length}',
        'source_asset_code': sourceAsset.code,
        'source_asset_issuer': sourceAsset.issuerId,
      },
      'destination_assets': destParam,
    };

    try {
      final resp = await getWithFallback(
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

  Future<double?> quoteXlmToUsdc(double sendAmountXlm) => quoteStrictSend(
    sourceAsset: xlm,
    sourceAmount: StellarBaseService.fmt7(sendAmountXlm),
    destinationAssets: [usdc],
  );

  Future<double?> quoteUsdcToXlm(double sendAmountUsdc) => quoteStrictSend(
    sourceAsset: usdc,
    sourceAmount: StellarBaseService.fmt7(sendAmountUsdc),
    destinationAssets: [xlm],
  );
}