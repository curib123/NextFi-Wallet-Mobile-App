import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final Future<String?> Function() tokenProvider;

  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _u(String path) => Uri.parse(
    baseUrl.endsWith('/')
        ? '${baseUrl.substring(0, baseUrl.length - 1)}$path'
        : '$baseUrl$path',
  );

  Future<Map<String, String>> _headers({required bool auth}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) {
        throw StateError(
          'Not authenticated: JWT is required for this endpoint.',
        );
      }
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  dynamic _decode(http.Response r) {
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  Exception _err(http.Response r) {
    final body = r.body.isEmpty ? null : r.body;
    return Exception('HTTP ${r.statusCode}: $body');
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final r = await _client.get(_u(path), headers: await _headers(auth: auth));
    if (r.statusCode >= 200 && r.statusCode < 300) return _decode(r);
    throw _err(r);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final r = await _client.post(
      _u(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return _decode(r);
    throw _err(r);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final r = await _client.patch(
      _u(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return _decode(r);
    throw _err(r);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final r = await _client.delete(
      _u(path),
      headers: await _headers(auth: auth),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return _decode(r);
    throw _err(r);
  }

  void dispose() => _client.close();
}
