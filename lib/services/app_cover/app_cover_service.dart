import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

class AppCoverConfig {
  const AppCoverConfig({required this.imageUrl, required this.isVisible});

  final String? imageUrl;
  final bool isVisible;

  bool get hasUsableImage =>
      isVisible && imageUrl != null && imageUrl!.trim().isNotEmpty;
}

class AppCoverService {
  AppCoverService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppCoverConfig?> getCurrent() async {
    final uri = Uri.parse('$centralized_baseUrl/app-cover');
    final res = await _client.get(
      uri,
      headers: const <String, String>{
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }

    final dynamic decoded = res.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final root = _unwrapMap(map);

    final imageUrl = _readOptionalText(root, const <String>[
      'imageUrl',
      'coverImageUrl',
      'image',
    ]);
    final isVisible = root['isVisible'] != false;

    return AppCoverConfig(imageUrl: imageUrl, isVisible: isVisible);
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  String? _readOptionalText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void dispose() => _client.close();
}
