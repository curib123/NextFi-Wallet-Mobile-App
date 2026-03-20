import 'package:next_fi/core/models/asset_model.dart';

class AssetCatalogPolicy {
  static const List<String> supportedAssetIds = <String>[
    'stellar',
    'usdc_stellar',
  ];

  static final Set<String> _supportedAssetIdSet = supportedAssetIds.toSet();

  static bool isSupportedAsset(AssetModel asset) {
    return _supportedAssetIdSet.contains(asset.id);
  }

  static List<AssetModel> filterSupportedAssets(Iterable<AssetModel> assets) {
    final byId = <String, AssetModel>{};
    for (final asset in assets) {
      if (!isSupportedAsset(asset)) continue;
      byId[asset.id] = asset;
    }

    return supportedAssetIds
        .map((id) => byId[id])
        .whereType<AssetModel>()
        .toList(growable: false);
  }
}
