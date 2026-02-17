import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/profile_exceptions.dart';
import '../helpers/profile_helpers.dart';
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

  Future<ProfileModel?> getMe() async {
    final res = await _client.get(
      ProfileHttp.uri(ProfileEndpoints.me()),
      headers: await _headers(),
    );

    ProfileHttp.ensureOk(res);
    final data = ProfileHttp.decodeJson<dynamic>(res);

    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic> && data.isEmpty) return null;
    if (data is Map<String, dynamic>) {
      final wrappedData = data['data'];
      final wrappedProfile = data['profile'];
      if (wrappedData is Map<String, dynamic>) {
        return ProfileModel.fromJson(wrappedData);
      }
      if (wrappedProfile is Map<String, dynamic>) {
        return ProfileModel.fromJson(wrappedProfile);
      }
      if (data.length == 1 &&
          (data.containsKey('data') || data.containsKey('profile')) &&
          wrappedData == null &&
          wrappedProfile == null) {
        return null;
      }
      return ProfileModel.fromJson(data);
    }
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

    if (data is Map<String, dynamic>) {
      return ProfileModel.fromJson(data);
    }

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

    if (data is Map<String, dynamic>) {
      return ProfileModel.fromJson(data);
    }

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
      return data['success'] == true;
    }

    return true;
  }
}
