import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../base_url/base_url.dart';
import '../models/profile_dtos.dart';
import '../models/profile_models.dart';
import 'profile_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class ProfileService {
  ProfileService({
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

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('$op failed (${res.statusCode}): ${res.body}');
  }

  Future<ProfileModel?> getMe() async {
    final res = await _client.get(
      _uri(ProfileEndpoints.me()),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /profile/me');
    final data = _decode(res);

    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      return ProfileModel.fromJson(data);
    }

    throw Exception('Unexpected response for GET /profile/me');
  }

  Future<ProfileModel> upsertMe(UpsertProfileRequest req) async {
    final res = await _client.put(
      _uri(ProfileEndpoints.me()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    _ensureOk(res, 'PUT /profile/me');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return ProfileModel.fromJson(data);
    }

    throw Exception('Unexpected response for PUT /profile/me');
  }

  Future<ProfileModel> patchMe(UpsertProfileRequest req) async {
    final res = await _client.patch(
      _uri(ProfileEndpoints.me()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    _ensureOk(res, 'PATCH /profile/me');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return ProfileModel.fromJson(data);
    }

    throw Exception('Unexpected response for PATCH /profile/me');
  }

  Future<bool> deleteMe() async {
    final res = await _client.delete(
      _uri(ProfileEndpoints.me()),
      headers: await _headers(),
    );

    _ensureOk(res, 'DELETE /profile/me');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return data['success'] == true;
    }

    return true;
  }
}
