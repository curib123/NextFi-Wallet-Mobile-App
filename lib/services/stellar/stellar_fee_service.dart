// stellar_fee_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:next_fi/services/fee_config/fee_config_core_service.dart';
import 'package:next_fi/services/fee_config/models/fee_config_models.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/stellar/stellar_base_service.dart';

/// Service for fee estimation and price quotes.
/// Fee policy comes from backend `/api/v1/fee-config`.
class StellarFeeService extends StellarBaseService {
  final String usdcIssuer;
  final FeeConfigCoreService feeConfigCore;

  FeeConfigModel? _cachedFeeConfig;
  DateTime? _cachedFeeConfigAt;
  static const Duration _feeConfigTtl = Duration(minutes: 3);

  StellarFeeService({
    required this.usdcIssuer,
    required StellarSDK sdk,
    StellarSDK? sdkQuickNode,
    FeeConfigCoreService? feeConfigCore,
    String? quickNodeUrlMainnet,
    String? quickNodeUrlTestnet,
    Map<String, String>? quickNodeDefaultHeaders,
  }) : feeConfigCore = feeConfigCore ?? FeeConfigCoreService.I,
       super(
         sdk: sdk,
         sdkQuickNode: sdkQuickNode,
         quickNodeUrlMainnet: quickNodeUrlMainnet,
         quickNodeUrlTestnet: quickNodeUrlTestnet,
         quickNodeDefaultHeaders: quickNodeDefaultHeaders,
       );

  Asset get xlm => Asset.NATIVE;
  Asset get usdc => AssetTypeCreditAlphaNum4('USDC', usdcIssuer);

  bool _isFeeConfigFresh() {
    final at = _cachedFeeConfigAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <= _feeConfigTtl;
  }

  Future<FeeConfigModel> ensureFeeConfigLoaded({bool refresh = false}) async {
    if (!refresh && _cachedFeeConfig != null && _isFeeConfigFresh()) {
      return _cachedFeeConfig!;
    }

    try {
      final cfg = await feeConfigCore.getCurrent();
      _cachedFeeConfig = cfg;
      _cachedFeeConfigAt = DateTime.now();
      return cfg;
    } catch (e) {
      if (!refresh && _cachedFeeConfig != null) {
        return _cachedFeeConfig!;
      }
      fail(
        'Unable to load fee configuration',
        technicalError: e,
        advice: 'Please try again in a moment.',
      );
    }
  }

  Future<String> getSwapFeeAddress({bool refresh = false}) async {
    final cfg = await ensureFeeConfigLoaded(refresh: refresh);
    final address = cfg.profitAddress.trim();

    if (address.isEmpty) {
      fail('Fee address is not configured', advice: 'Please contact support.');
    }
    return address;
  }

  Future<double> getSwapFeeRate({bool refresh = false}) async {
    final cfg = await ensureFeeConfigLoaded(refresh: refresh);
    if (!cfg.isEnabled) return 0.0;
    return cfg.swapFeeRate;
  }

  Future<double> computeDynamicFeeXlm() async {
    final cfg = await ensureFeeConfigLoaded();
    final feeUsd = cfg.txFeeUsd;

    if (!cfg.isEnabled || feeUsd <= 0) return 0.0;

    try {
      final x1 = await quoteUsdcToXlm(feeUsd);
      if (x1 != null && x1 > 0) return x1;
    } catch (_) {}

    try {
      final usdcPer1Xlm = await quoteXlmToUsdc(1.0);
      if (usdcPer1Xlm != null && usdcPer1Xlm > 0) {
        final x2 = feeUsd / usdcPer1Xlm;
        if (x2 > 0) return x2;
      }
    } catch (_) {}

    return feeUsd;
  }

  Future<int> getCurrentFeeStroops() async {
    final xlm = await computeDynamicFeeXlm();
    return (xlm * 1e7).ceil();
  }

  Future<double> getCurrentFeeXlm() async =>
      fromStroops(await getCurrentFeeStroops());

  Future<String> getCurrentFeeLabel() async =>
      '${(await getCurrentFeeXlm()).toStringAsFixed(7)} XLM';

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
