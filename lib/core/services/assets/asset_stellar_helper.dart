import 'package:next_fi/core/models/asset_model.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class AssetStellarHelper {
  const AssetStellarHelper._();

  static bool isStellarAsset(AssetModel asset) =>
      asset.chain.trim().toLowerCase() == 'stellar';

  static Asset toStellarAsset(AssetModel asset) {
    if (asset.isNative) {
      return Asset.NATIVE;
    }

    final code = (asset.assetCode ?? asset.symbol).trim();
    final issuer = (asset.issuer ?? '').trim();
    if (code.isEmpty || issuer.isEmpty) {
      throw ArgumentError(
        'Asset ${asset.id} is missing Stellar assetCode or issuer.',
      );
    }

    return code.length <= 4
        ? AssetTypeCreditAlphaNum4(code, issuer)
        : AssetTypeCreditAlphaNum12(code, issuer);
  }

  static String assetKey(AssetModel asset) {
    if (asset.isNative) return 'XLM';
    final code = (asset.assetCode ?? asset.symbol).trim().toUpperCase();
    final issuer = (asset.issuer ?? '').trim();
    return issuer.isEmpty ? code : '$code:$issuer';
  }
}
