import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/app/viewmodels/asset_catalog_deduper.dart';
import 'package:next_fi/core/models/asset_model.dart';

void main() {
  test('dedupeAssetCatalog removes duplicate Stellar assets by identity', () {
    final assets = <AssetModel>[
      const AssetModel(
        id: 'stellar',
        name: 'Stellar',
        symbol: 'XLM',
        isNative: true,
        kind: AssetKind.native,
      ),
      const AssetModel(
        id: 'stellar-copy',
        name: 'Stellar Copy',
        symbol: 'XLM',
        isNative: true,
        kind: AssetKind.native,
      ),
      const AssetModel(
        id: 'usdc-a',
        name: 'USD Coin',
        symbol: 'USDC',
        assetCode: 'USDC',
        issuer: 'GISSUER',
      ),
      const AssetModel(
        id: 'usdc-b',
        name: 'USD Coin Duplicate',
        symbol: 'USDC',
        assetCode: 'USDC',
        issuer: 'GISSUER',
      ),
    ];

    final deduped = dedupeAssetCatalog(assets);

    expect(deduped, hasLength(2));
    expect(deduped.first.id, 'stellar');
    expect(deduped.last.id, 'usdc-a');
  });
}
