import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../base_url/base_url.dart';
import '../models/verification_models.dart';
import 'verification_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class VerificationService {
  VerificationService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Uri _uri(String path) {
    final base = cetralized_baseUrl.endsWith('/')
        ? cetralized_baseUrl.substring(0, cetralized_baseUrl.length - 1)
        : cetralized_baseUrl;

    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw Exception('Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _tokenOrThrow() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw Exception('Missing JWT token');
    }
    return token;
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('$op failed (${res.statusCode}): ${res.body}');
  }

  Future<VerificationModel> getMe() async {
    final res = await _client.get(
      _uri(VerificationEndpoints.me()),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /verification/me');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return VerificationModel.fromJson(data);
    }

    throw Exception('Unexpected response for GET /verification/me');
  }

  Future<VerificationModel> submit({
    required File selfie,
    String? paymentAccountId,
  }) async {
    final token = await _tokenOrThrow();

    final req = http.MultipartRequest(
      'POST',
      _uri(VerificationEndpoints.submit()),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    if (paymentAccountId != null && paymentAccountId.trim().isNotEmpty) {
      req.fields['paymentAccountId'] = paymentAccountId;
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    _ensureOk(res, 'POST /verification/submit');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return VerificationModel.fromJson(data);
    }

    throw Exception('Unexpected response for POST /verification/submit');
  }
}
