import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class AccountState {
  static const String nativeAssetKey = 'native';

  final Map<String, double> balancesByAssetKey;
  final Map<String, bool> trustlinesByAssetKey;
  final DateTime updatedAt;
  const AccountState({
    required this.balancesByAssetKey,
    required this.trustlinesByAssetKey,
    required this.updatedAt,
  });

  static String assetKeyForAsset(Asset asset) {
    if (asset is AssetTypeNative) return nativeAssetKey;
    if (asset is AssetTypeCreditAlphaNum) return asset.code;
    return nativeAssetKey;
  }

  double balanceFor(String assetKey) => balancesByAssetKey[assetKey] ?? 0.0;
  bool hasTrustlineFor(String assetKey) => trustlinesByAssetKey[assetKey] ?? false;

  double get xlm => balanceFor(nativeAssetKey);
  double get usdc => balanceFor('USDC');
  bool get hasUsdcTrustline => hasTrustlineFor('USDC');
}

class FeeEstimate {
  final int perOpStroops;
  final int totalStroops;
  final double totalXlm;
  final int baseFee;
  final int opCount;
  final int percentile;
  final DateTime ledgerClosedAt;
  const FeeEstimate({
    required this.perOpStroops,
    required this.totalStroops,
    required this.totalXlm,
    required this.baseFee,
    required this.opCount,
    required this.percentile,
    required this.ledgerClosedAt,
  });
}

class PairPrice {
  final String baseAssetKey;
  final String counterAssetKey;
  final double counterPerBase; // counter/base price
  double get basePerCounter => counterPerBase == 0 ? 0 : 1 / counterPerBase;
  final DateTime at;
  const PairPrice({
    required this.baseAssetKey,
    required this.counterAssetKey,
    required this.counterPerBase,
    required this.at,
  });

  double get usdcPerXlm => counterPerBase;
  double get xlmPerUsdc => basePerCounter;
}
