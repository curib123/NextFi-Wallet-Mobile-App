import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';

class AppCoverConfig {
  const AppCoverConfig({
    required this.imageUrl,
    required this.isVisible,
  });

  final String? imageUrl;
  final bool isVisible;

  bool get hasUsableImage =>
      isVisible && imageUrl != null && imageUrl!.trim().isNotEmpty;
}

class AppCoverService {
  AppCoverService({http.Client? client, TokenStorage? tokenStorage})
    : _client = client ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  Future<AppCoverConfig?> getCurrent() async {
    final token = await _tokenStorage.accessToken;
    if (token == null || token.trim().isEmpty) return null;

    final uri = Uri.parse('$centralized_baseUrl/app-cover');
    final res = await _client.get(
      uri,
      headers: <String, String>{
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer $token',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }

    final dynamic decoded = res.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    final root = _unwrapMap(map);

    final imageUrl = _readOptionalText(root, const <String>[
      'imageUrl',
      'coverImageUrl',
      'image',
    ]);
    final isVisible = root['isVisible'] != false;

    return AppCoverConfig(
      imageUrl: imageUrl,
      isVisible: isVisible,
    );
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
