import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/base_url/base_url.dart';

class AssetCatalogService {
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const String _catalogCacheKey = 'nextfi.asset_catalog.cache.v1';
  static const String _catalogCacheUpdatedAtKey =
      'nextfi.asset_catalog.cache.updated_at.v1';

  Future<List<AssetModel>> fetchAssets() async {
    final res = await http.get(Uri.parse('$centralizedBaseUrl/assets'));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to load asset catalog (${res.statusCode})');
    }

    if (res.body.isEmpty) return const [];

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => AssetModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<AssetModel>> readCachedAssets() async {
    try {
      final raw = await _store.read(key: _catalogCacheKey);
      if (raw == null || raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => AssetModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeCachedAssets(List<AssetModel> assets) async {
    try {
      await _store.write(
        key: _catalogCacheKey,
        value: jsonEncode(assets.map((asset) => asset.toJson()).toList()),
      );
      await _store.write(
        key: _catalogCacheUpdatedAtKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<List<AssetModel>> fetchAssetsAndUpdateCache() async {
    final assets = await fetchAssets();
    await writeCachedAssets(assets);
    return assets;
  }
}
