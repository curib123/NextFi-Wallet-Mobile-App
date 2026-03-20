import 'dart:convert';
import 'package:http/http.dart' as http;

import 'wallet_endpoints.dart';
import '../helpers/wallet_helpers.dart';
import '../helpers/wallet_exceptions.dart';
import '../models/wallet_models.dart';
import '../models/wallet_dtos.dart';

typedef TokenProvider = Future<String?> Function();

class WalletService {
  WalletService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'wallet',
    'wallets',
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

  WalletPaginationMeta _extractMeta(
    dynamic data, {
    required int fallbackCount,
  }) {
    final map = _asStringKeyMap(data);
    if (map != null) {
      final meta = _asStringKeyMap(map['meta']);
      if (meta != null) return WalletPaginationMeta.fromJson(meta);

      final pagination = _asStringKeyMap(map['pagination']);
      if (pagination != null) return WalletPaginationMeta.fromJson(pagination);

      if (map.containsKey('page') ||
          map.containsKey('limit') ||
          map.containsKey('total') ||
          map.containsKey('totalPages') ||
          map.containsKey('total_pages')) {
        return WalletPaginationMeta.fromJson(map);
      }
    }

    return WalletPaginationMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  Future<WalletPagedResponse> listPaged({
    WalletListQuery query = const WalletListQuery(),
  }) async {
    final res = await _client.get(
      WalletHttp.uri(WalletEndpoints.list(), queryParams: query.toQueryMap()),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);

    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'wallets', 'list'],
    );
    final parsedItems = items.map(WalletAddress.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: parsedItems.length);

    return WalletPagedResponse(items: parsedItems, meta: meta);
  }

  Future<List<WalletAddress>> list({
    WalletListQuery query = const WalletListQuery(),
  }) async {
    final page = await listPaged(query: query);
    return page.items;
  }

  Future<WalletAddress> create(CreateWalletRequest req) async {
    final res = await _client.post(
      WalletHttp.uri(WalletEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'wallet']);
    if (map != null) return WalletAddress.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /wallets',
      body: res.body,
    );
  }

  Future<WalletAddress> update(String id, UpdateWalletRequest req) async {
    final res = await _client.patch(
      WalletHttp.uri(WalletEndpoints.update(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'wallet']);
    if (map != null) return WalletAddress.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /wallets/$id',
      body: res.body,
    );
  }

  Future<WalletAddress> updateLabel(String id, {required String label}) {
    return update(id, UpdateWalletRequest(label: label));
  }

  Future<WalletAddress> setActive(String id) async {
    final res = await _client.patch(
      WalletHttp.uri(WalletEndpoints.setActive(id)),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'wallet']);
    if (map != null) return WalletAddress.fromJson(map);

    return WalletAddress(
      id: id,
      publicAddress: '',
      network: 'stellar',
      isActive: true,
    );
  }

  Future<WalletAddress> remove(String id) async {
    final res = await _client.delete(
      WalletHttp.uri(WalletEndpoints.remove(id)),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);

    if (res.body.isEmpty) {
      return WalletAddress(id: id, publicAddress: '', network: 'stellar');
    }

    final data = WalletHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'wallet']);
    if (map != null) return WalletAddress.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for DELETE /wallets/$id',
      body: res.body,
    );
  }

  void dispose() {
    _client.close();
  }
}
