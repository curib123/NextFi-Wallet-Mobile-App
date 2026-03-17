import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/base_url/base_url.dart';

class AssetCatalogService {
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
}
