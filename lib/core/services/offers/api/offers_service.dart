import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/offers_exceptions.dart';
import '../helpers/offers_helpers.dart';
import '../models/offers_dtos.dart';
import '../models/offers_models.dart';
import 'offers_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class OffersService {
  OffersService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'offer',
    'offers',
    'meta',
    'pagination',
    'page',
    'limit',
    'total',
    'totalPages',
    'total_pages',
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
  };

  Future<Map<String, String>> _publicHeaders() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      return const {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

  Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k.toString()));

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

    final map = _asStringKeyMap(data);
    if (map == null || map.isEmpty) return null;

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final extracted = _extractMap(map[key], keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
    }

    if (!_isEnvelopeMap(map)) return map;

    for (final value in map.values) {
      final extracted = _extractMap(value, keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
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
      final items = data
          .map(_asStringKeyMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (items.isNotEmpty) return items;

      for (final item in data) {
        final nested = _extractListMaps(item, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    final map = _asStringKeyMap(data);
    if (map == null) return const [];

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final nested = _extractListMaps(map[key], keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    for (final value in map.values) {
      final nested = _extractListMaps(value, keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    return const [];
  }

  OffersMeta _extractMeta(dynamic data, {required int fallbackCount}) {
    final map = _asStringKeyMap(data);
    if (map != null) {
      final meta = _asStringKeyMap(map['meta']);
      if (meta != null) return OffersMeta.fromJson(meta);

      final pagination = _asStringKeyMap(map['pagination']);
      if (pagination != null) return OffersMeta.fromJson(pagination);

      if (map.containsKey('page') ||
          map.containsKey('limit') ||
          map.containsKey('total') ||
          map.containsKey('totalPages') ||
          map.containsKey('total_pages')) {
        return OffersMeta.fromJson(map);
      }
    }

    return OffersMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  Future<OffersPagedResponse> listPublicPaged({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final res = await _client.get(
      OffersHttp.uri(
        OffersEndpoints.publicList(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _publicHeaders(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    ).map(OfferModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OffersPagedResponse(items: items, meta: meta);
  }

  Future<List<OfferModel>> listPublic({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final page = await listPublicPaged(query: query);
    return page.items;
  }

  Future<OfferModel> getPublicById(String id) async {
    final res = await _client.get(
      OffersHttp.uri(OffersEndpoints.publicGetOne(id)),
      headers: await _publicHeaders(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'offer']);
    if (map != null) return OfferModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /offers/$id',
      body: res.body,
    );
  }

  Future<OfferModel> create(CreateOfferRequest req) async {
    final res = await _client.post(
      OffersHttp.uri(OffersEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'offer']);
    if (map != null) return OfferModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /offers',
      body: res.body,
    );
  }

  Future<OfferModel> update(String id, UpdateOfferRequest req) async {
    final res = await _client.patch(
      OffersHttp.uri(OffersEndpoints.update(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'offer']);
    if (map != null) return OfferModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /offers/$id',
      body: res.body,
    );
  }

  Future<OfferModel> pause(String id) async {
    final res = await _client.patch(
      OffersHttp.uri(OffersEndpoints.pause(id)),
      headers: await _headers(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'offer']);
    if (map != null) return OfferModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /offers/$id/pause',
      body: res.body,
    );
  }

  Future<OfferModel> resume(String id) async {
    final res = await _client.patch(
      OffersHttp.uri(OffersEndpoints.resume(id)),
      headers: await _headers(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'offer']);
    if (map != null) return OfferModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /offers/$id/resume',
      body: res.body,
    );
  }

  Future<bool> cancel(String id) async {
    final res = await _client.delete(
      OffersHttp.uri(OffersEndpoints.cancel(id)),
      headers: await _headers(),
    );
    OffersHttp.ensureOk(res);
    return true;
  }

  Future<OffersPagedResponse> listMinePaged({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final res = await _client.get(
      OffersHttp.uri(OffersEndpoints.mine(), queryParams: query.toQueryMap()),
      headers: await _headers(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    ).map(OfferModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OffersPagedResponse(items: items, meta: meta);
  }

  Future<List<OfferModel>> listMine({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final page = await listMinePaged(query: query);
    return page.items;
  }

  Future<OffersPagedResponse> listAdminPaged({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final res = await _client.get(
      OffersHttp.uri(
        OffersEndpoints.adminList(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );
    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    ).map(OfferModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OffersPagedResponse(items: items, meta: meta);
  }

  Future<List<OfferModel>> listAdmin({
    OffersListQuery query = const OffersListQuery(),
  }) async {
    final page = await listAdminPaged(query: query);
    return page.items;
  }

  void dispose() => _client.close();
}
