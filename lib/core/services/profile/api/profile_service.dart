import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/profile_exceptions.dart';
import '../helpers/profile_helpers.dart';
import '../models/profile_dtos.dart';
import '../models/profile_models.dart';
import 'profile_endpoints.dart';


typedef TokenProvider = Future<String?> Function();

class ProfileService {
  ProfileService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'profile',
    'item',
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
    'meta',
    'pagination',
    'page',
    'limit',
    'total',
    'totalPages',
  };

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k.toString()));

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _extractMap(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8) return null;
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;

    if (data is List) {
      if (data.isEmpty) return null;
      for (final item in data) {
        final extracted = _extractMap(item, keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }
      return null;
    }

    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;

      for (final key in keys) {
        if (!data.containsKey(key)) continue;
        final extracted = _extractMap(data[key], keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }

      if (!_isEnvelopeMap(data)) return data;

      for (final value in data.values) {
        final extracted = _extractMap(value, keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }
    }

    return null;
  }

  Future<ProfileModel?> getMe() async {
    final res = await _client.get(
      ProfileHttp.uri(ProfileEndpoints.me()),
      headers: await _headers(),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);
    if (data == null) return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic>) {
      final hasWrapper =
          data.containsKey('data') ||
          data.containsKey('profile') ||
          data.containsKey('item');
      if (hasWrapper) {
        final wrapped = data['data'] ?? data['profile'] ?? data['item'];
        if (wrapped == null) return null;
        if (wrapped is String && wrapped.trim().toLowerCase() == 'null') {
          return null;
        }
      }
    }

    final map = _extractMap(data, keys: const ['data', 'profile', 'item']);
    if (map != null) return ProfileModel.fromJson(map);
    if (data is List && data.isEmpty) return null;

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /profile/me',
      body: res.body,
    );
  }

  Future<ProfileModel> upsertMe(UpsertProfileRequest req) async {
    final res = await _client.put(
      ProfileHttp.uri(ProfileEndpoints.me()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);

    final map = _extractMap(data, keys: const ['data', 'profile', 'item']);
    if (map != null) return ProfileModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PUT /profile/me',
      body: res.body,
    );
  }

  Future<ProfileModel> patchMe(UpsertProfileRequest req) async {
    final res = await _client.patch(
      ProfileHttp.uri(ProfileEndpoints.me()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);

    final map = _extractMap(data, keys: const ['data', 'profile', 'item']);
    if (map != null) return ProfileModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /profile/me',
      body: res.body,
    );
  }

  Future<bool> deleteMe() async {
    final res = await _client.delete(
      ProfileHttp.uri(ProfileEndpoints.me()),
      headers: await _headers(),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      final wrapped = data['data'];
      if (wrapped is Map<String, dynamic>) return wrapped['success'] == true;
      return data['success'] == true;
    }

    return true;
  }

}
