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
  }) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;

    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;

      for (final key in keys) {
        final nested = data[key];
        if (nested is Map<String, dynamic>) return nested;
      }

      return data;
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

  Future<MerchantRequestStatusModel> getMerchantRequestStatus() async {
    final res = await _client.get(
      ProfileHttp.uri(ProfileEndpoints.merchantRequestStatus()),
      headers: await _headers(),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(
      data,
      keys: const ['data', 'merchantRequest', 'merchant_request'],
    );

    if (map != null) {
      return MerchantRequestStatusModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /profile/me/merchant-request',
      body: res.body,
    );
  }

  Future<MerchantRequestStatusModel> requestMerchantAccess({
    String? note,
  }) async {
    final req = RequestMerchantAccessRequest(note: note);
    final res = await _client.post(
      ProfileHttp.uri(ProfileEndpoints.requestMerchantAccess()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(
      data,
      keys: const ['data', 'merchantRequest', 'merchant_request'],
    );

    if (map != null) {
      return MerchantRequestStatusModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /profile/me/request-merchant',
      body: res.body,
    );
  }
}
