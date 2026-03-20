import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/assets/asset_catalog_policy.dart';

void main() {
  test('filterSupportedAssets keeps only wallet-supported XLM and USDC', () {
    final assets = <AssetModel>[
      const AssetModel(
        id: 'usdt_stellar',
        name: 'Tether',
        symbol: 'USDT',
        assetCode: 'USDT',
        issuer: 'GUSDT',
      ),
      const AssetModel(
        id: 'stellar',
        name: 'Stellar Lumens',
        symbol: 'XLM',
        isNative: true,
        kind: AssetKind.native,
      ),
      const AssetModel(
        id: 'aqua_stellar',
        name: 'AQUA',
        symbol: 'AQUA',
        assetCode: 'AQUA',
        issuer: 'GAQUA',
      ),
      const AssetModel(
        id: 'usdc_stellar',
        name: 'USD Coin',
        symbol: 'USDC',
        assetCode: 'USDC',
        issuer: 'GUSDC',
      ),
    ];

    final filtered = AssetCatalogPolicy.filterSupportedAssets(assets);

    expect(filtered.map((asset) => asset.id).toList(), <String>[
      'stellar',
      'usdc_stellar',
    ]);
  });
}
