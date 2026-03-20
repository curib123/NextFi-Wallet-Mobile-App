import 'package:http/http.dart' as http;

import '../helpers/offer_payment_method_exceptions.dart';
import '../helpers/offer_payment_method_helpers.dart';
import '../models/offer_payment_method_dtos.dart';
import '../models/offer_payment_method_models.dart';
import 'offer_payment_method_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class OfferPaymentMethodService {
  OfferPaymentMethodService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'offer',
    'offers',
    'paymentMethod',
    'paymentMethods',
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

  OfferPaymentMethodMeta _extractMeta(
    dynamic data, {
    required int fallbackCount,
  }) {
    final map = _asStringKeyMap(data);
    if (map != null) {
      final meta = _asStringKeyMap(map['meta']);
      if (meta != null) return OfferPaymentMethodMeta.fromJson(meta);

      final pagination = _asStringKeyMap(map['pagination']);
      if (pagination != null)
        return OfferPaymentMethodMeta.fromJson(pagination);

      if (map.containsKey('page') ||
          map.containsKey('limit') ||
          map.containsKey('total') ||
          map.containsKey('totalPages') ||
          map.containsKey('total_pages')) {
        return OfferPaymentMethodMeta.fromJson(map);
      }
    }

    return OfferPaymentMethodMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  Future<OfferPaymentMethodPagedResponse> listAll({
    String? offerId,
    String? paymentMethodId,
    bool? activeOnly,
    String? searchQuery,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{};
    if (offerId != null) queryParams['offerId'] = offerId;
    if (paymentMethodId != null)
      queryParams['paymentMethodId'] = paymentMethodId;
    if (activeOnly != null) queryParams['activeOnly'] = activeOnly.toString();
    if (searchQuery != null) queryParams['q'] = searchQuery;
    queryParams['page'] = page.toString();
    queryParams['limit'] = limit.toString();

    final res = await _client.get(
      OfferPaymentMethodHttp.uri(
        OfferPaymentMethodEndpoints.list(),
        queryParams: queryParams,
      ),
      headers: await _publicHeaders(),
    );
    OfferPaymentMethodHttp.ensureOk(res);
    final data = OfferPaymentMethodHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offerPaymentMethods', 'list'],
    ).map(OfferPaymentMethodResponse.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OfferPaymentMethodPagedResponse(items: items, meta: meta);
  }

  Future<OfferPaymentMethodResponse> getById(String id) async {
    final res = await _client.get(
      OfferPaymentMethodHttp.uri(OfferPaymentMethodEndpoints.getById(id)),
      headers: await _publicHeaders(),
    );
    OfferPaymentMethodHttp.ensureOk(res);
    final data = OfferPaymentMethodHttp.decodeJson<dynamic>(res);
    final map = _extractMap(
      data,
      keys: const ['data', 'item', 'offerPaymentMethod'],
    );
    if (map != null) return OfferPaymentMethodResponse.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /offer-payment-methods/$id',
      body: res.body,
    );
  }

  Future<OfferPaymentMethodPagedResponse> getPaymentMethodsForOffer(
    String offerId,
  ) async {
    final res = await _client.get(
      OfferPaymentMethodHttp.uri(
        OfferPaymentMethodEndpoints.getByOffer(offerId),
      ),
      headers: await _publicHeaders(),
    );
    OfferPaymentMethodHttp.ensureOk(res);
    final data = OfferPaymentMethodHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'paymentMethods', 'list'],
    ).map(OfferPaymentMethodResponse.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OfferPaymentMethodPagedResponse(items: items, meta: meta);
  }

  Future<OfferPaymentMethodPagedResponse> getOffersForPaymentMethod(
    String paymentMethodId,
  ) async {
    final res = await _client.get(
      OfferPaymentMethodHttp.uri(
        OfferPaymentMethodEndpoints.getByPaymentMethod(paymentMethodId),
      ),
      headers: await _publicHeaders(),
    );
    OfferPaymentMethodHttp.ensureOk(res);
    final data = OfferPaymentMethodHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'offers', 'list'],
    ).map(OfferPaymentMethodResponse.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return OfferPaymentMethodPagedResponse(items: items, meta: meta);
  }

  void dispose() => _client.close();
}
