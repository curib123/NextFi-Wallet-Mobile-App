import 'package:next_fi/core/models/asset_model.dart';

List<AssetModel> dedupeAssetCatalog(List<AssetModel> assets) {
  final seen = <String>{};
  final next = <AssetModel>[];

  String keyFor(AssetModel asset) {
    if (asset.isNative) {
      return '${asset.chain.toLowerCase()}:native:${asset.network.toLowerCase()}';
    }

    final code = (asset.assetCode ?? asset.symbol).trim().toUpperCase();
    final issuer = (asset.issuer ?? '').trim().toUpperCase();
    return '${asset.chain.toLowerCase()}:${asset.network.toLowerCase()}:$code:$issuer';
  }

  for (final asset in assets) {
    final key = keyFor(asset);
    if (!seen.add(key)) continue;
    next.add(asset);
  }

  return next;
}
