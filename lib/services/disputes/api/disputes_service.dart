import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../helpers/disputes_exceptions.dart';
import '../helpers/disputes_helpers.dart';
import '../models/disputes_dtos.dart';
import '../models/disputes_models.dart';
import 'disputes_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class DisputesService {
  DisputesService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _allowedImageExt = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'dispute',
    'disputes',
    'meta',
    'pagination',
    'page',
    'limit',
    'total',
    'totalPages',
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
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

  Future<String> _tokenOrThrow() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }
    return token;
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

  List<Map<String, dynamic>> _extractListMaps(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8 || data == null) return const [];

    if (data is List) {
      final items = data.whereType<Map<String, dynamic>>().toList();
      if (items.isNotEmpty) return items;
      for (final item in data) {
        final nested = _extractListMaps(item, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        if (!data.containsKey(key)) continue;
        final nested = _extractListMaps(
          data[key],
          keys: keys,
          depth: depth + 1,
        );
        if (nested.isNotEmpty) return nested;
      }
      for (final value in data.values) {
        final nested = _extractListMaps(value, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  void _ensureImagePathAllowed(String path, {required String label}) {
    final normalized = path.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    final ext = dot >= 0 ? normalized.substring(dot + 1) : '';
    if (!_allowedImageExt.contains(ext)) {
      throw ApiException(400, '$label must be JPG/JPEG/PNG/WEBP.');
    }
  }

  Future<DisputeModel> openDispute(OpenDisputeRequest req) async {
    final res = await _client.post(
      DisputesHttp.uri(DisputesEndpoints.open()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    DisputesHttp.ensureOk(res);
    final data = DisputesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'dispute', 'item']);
    if (map != null) return DisputeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /disputes',
      body: res.body,
    );
  }

  Future<List<DisputeModel>> listMyDisputes(DisputesQuery query) async {
    final res = await _client.get(
      DisputesHttp.uri(
        DisputesEndpoints.myList(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    DisputesHttp.ensureOk(res);
    final data = DisputesHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'disputes', 'list'],
    );
    return items.map(DisputeModel.fromJson).toList();
  }

  Future<List<DisputeModel>> listSellerDisputes(DisputesQuery query) async {
    final res = await _client.get(
      DisputesHttp.uri(
        DisputesEndpoints.sellerList(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    DisputesHttp.ensureOk(res);
    final data = DisputesHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'disputes', 'list'],
    );
    return items.map(DisputeModel.fromJson).toList();
  }

  Future<DisputeModel> uploadEvidence(
    String disputeId, {
    required File image,
    String? note,
  }) async {
    _ensureImagePathAllowed(image.path, label: 'Dispute evidence');
    final token = await _tokenOrThrow();

    final req =
        http.MultipartRequest(
            'POST',
            DisputesHttp.uri(DisputesEndpoints.uploadEvidence(disputeId)),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..files.add(await http.MultipartFile.fromPath('image', image.path));

    if (note != null && note.trim().isNotEmpty) {
      req.fields['note'] = note.trim();
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    DisputesHttp.ensureOk(res);
    final data = DisputesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'dispute', 'item']);
    if (map != null) return DisputeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /disputes/$disputeId/evidence',
      body: res.body,
    );
  }
}
