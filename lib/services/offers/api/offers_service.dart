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
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
  };

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k.toString()));

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

  Future<List<OfferModel>> listPublicOffers(OffersQuery query) async {
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
    );
    return items.map(OfferModel.fromJson).toList();
  }

  Future<List<OfferModel>> listRecommendedOffers(OffersQuery query) async {
    final res = await _client.get(
      OffersHttp.uri(
        OffersEndpoints.recommendedFeed(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    );
    return items.map(OfferModel.fromJson).toList();
  }

  Future<OfferModel> getPublicOffer(String id) async {
    final res = await _client.get(
      OffersHttp.uri(OffersEndpoints.publicById(id)),
      headers: await _publicHeaders(),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'offer', 'item']);
    if (map != null) return OfferModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /offers/$id',
      body: res.body,
    );
  }

  Future<List<OfferModel>> listMyOffers(OffersQuery query) async {
    final res = await _client.get(
      OffersHttp.uri(OffersEndpoints.myList(), queryParams: query.toQueryMap()),
      headers: await _headers(),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    );
    return items.map(OfferModel.fromJson).toList();
  }

  Future<OfferModel> createMyOffer(CreateOfferRequest req) async {
    final res = await _client.post(
      OffersHttp.uri(OffersEndpoints.createMyOffer()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'offer', 'item']);
    if (map != null) return OfferModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /offers/me',
      body: res.body,
    );
  }

  Future<OfferModel> patchMyOffer(String id, UpdateOfferRequest req) async {
    final res = await _client.patch(
      OffersHttp.uri(OffersEndpoints.patchMyOffer(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'offer', 'item']);
    if (map != null) return OfferModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /offers/me/$id',
      body: res.body,
    );
  }

  Future<bool> deleteMyOffer(String id) async {
    final res = await _client.delete(
      OffersHttp.uri(OffersEndpoints.deleteMyOffer(id)),
      headers: await _headers(),
    );

    OffersHttp.ensureOk(res);
    final data = OffersHttp.decodeJson<dynamic>(res);
    if (data is Map<String, dynamic>) {
      final wrapped = data['data'];
      if (wrapped is Map<String, dynamic>) return wrapped['success'] == true;
      return data['success'] == true;
    }
    return true;
  }
}
