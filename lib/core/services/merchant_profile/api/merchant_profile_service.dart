import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../helpers/merchant_profile_exceptions.dart';
import '../helpers/merchant_profile_helpers.dart';
import '../models/merchant_profile_dtos.dart';
import '../models/merchant_profile_models.dart';
import '../models/merchant_tier_progress_models.dart';
import 'merchant_profile_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class MerchantProfileService {
  MerchantProfileService({required this.tokenProvider, http.Client? client})
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

  Future<String> _tokenOrThrow() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }
    return token;
  }

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
      for (final key in const [
        'data',
        'merchantProfile',
        'merchant_profile',
        'profile',
      ]) {
        final v = data[key];
        if (v is Map<String, dynamic>) return v;
      }
      // Not a pure envelope — return as-is
      final envelopeOnly = {'data', 'success', 'message', 'error', 'meta'};
      if (!data.keys.every((k) => envelopeOnly.contains(k))) return data;
    }
    return null;
  }

  // ── User routes ─────────────────────────────────────────────────────────────

  /// GET /merchant-profiles/me
  /// Returns null if the user has not submitted a merchant application yet.
  Future<MerchantProfileModel?> getMe() async {
    try {
      final res = await _client.get(
        MerchantProfileHttp.uri(MerchantProfileEndpoints.me()),
        headers: await _headers(),
      );
      MerchantProfileHttp.ensureOk(res);
      final data = MerchantProfileHttp.decodeJson<dynamic>(res);
      final map = _extractMap(data);
      if (map != null) return MerchantProfileModel.fromJson(map);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  /// GET /merchant-profiles/me/tier-progress
  /// Returns null if user is not merchant yet or endpoint is unavailable for current state.
  Future<MerchantTierProgressModel?> getTierProgress() async {
    try {
      final res = await _client.get(
        MerchantProfileHttp.uri(MerchantProfileEndpoints.meTierProgress()),
        headers: await _headers(),
      );
      MerchantProfileHttp.ensureOk(res);
      final data = MerchantProfileHttp.decodeJson<dynamic>(res);
      final map = _extractMap(data) ?? _asDataMap(data);
      if (map != null) return MerchantTierProgressModel.fromJson(map);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403) return null;
      rethrow;
    }
    return null;
  }

  /// POST /merchant-profiles/request  — submit or re-submit merchant application.
  Future<MerchantProfileModel> request(
    RequestMerchantProfileRequest req,
  ) async {
    final res = await _client.post(
      MerchantProfileHttp.uri(MerchantProfileEndpoints.request()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    MerchantProfileHttp.ensureOk(res);
    final data = MerchantProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantProfileModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /merchant-profiles/request',
      body: res.body,
    );
  }

  /// PATCH /merchant-profiles/me  — update profile details (APPROVED merchants only).
  Future<MerchantProfileModel> updateMe(
    UpdateMerchantProfileRequest req,
  ) async {
    final res = await _client.patch(
      MerchantProfileHttp.uri(MerchantProfileEndpoints.me()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    MerchantProfileHttp.ensureOk(res);
    final data = MerchantProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantProfileModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /merchant-profiles/me',
      body: res.body,
    );
  }

  /// PATCH /merchant-profiles/me/availability  — set availability schedule.
  Future<MerchantProfileModel> updateAvailability(
    UpdateMerchantAvailabilityRequest req,
  ) async {
    final res = await _client.patch(
      MerchantProfileHttp.uri(MerchantProfileEndpoints.meAvailability()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    MerchantProfileHttp.ensureOk(res);
    final data = MerchantProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantProfileModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /merchant-profiles/me/availability',
      body: res.body,
    );
  }

  /// POST /merchant-profiles/me/business-docs  — upload business documents.
  /// At least one of [businessDocument] or [authorizationLetter] is required.
  Future<MerchantProfileModel> uploadBusinessDocs({
    File? businessDocument,
    File? authorizationLetter,
  }) async {
    if (businessDocument == null && authorizationLetter == null) {
      throw ApiException(400, 'At least one document file is required.');
    }

    final token = await _tokenOrThrow();
    final req =
        http.MultipartRequest(
            'POST',
            MerchantProfileHttp.uri(MerchantProfileEndpoints.meBusinessDocs()),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json';

    if (businessDocument != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'businessDocument',
          businessDocument.path,
        ),
      );
    }
    if (authorizationLetter != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'authorizationLetter',
          authorizationLetter.path,
        ),
      );
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    MerchantProfileHttp.ensureOk(res);
    final data = MerchantProfileHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantProfileModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /merchant-profiles/me/business-docs',
      body: res.body,
    );
  }

  /// GET /merchant-profiles/public/:userId  — public merchant profile (APPROVED only).
  Future<MerchantProfileModel?> getPublic(String userId) async {
    try {
      final res = await _client.get(
        MerchantProfileHttp.uri(MerchantProfileEndpoints.publicProfile(userId)),
        headers: await _headers(),
      );
      MerchantProfileHttp.ensureOk(res);
      final data = MerchantProfileHttp.decodeJson<dynamic>(res);
      final map = _extractMap(data);
      if (map != null) return MerchantProfileModel.fromJson(map);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }

  void dispose() => _client.close();
}

Map<String, dynamic>? _asDataMap(dynamic data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final nested = map['data'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  if (map.containsKey('currentTier') ||
      map.containsKey('tiers') ||
      map.containsKey('nextTier')) {
    return map;
  }
  return null;
}
