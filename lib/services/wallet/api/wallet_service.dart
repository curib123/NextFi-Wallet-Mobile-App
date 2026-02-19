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

  /// ── GET /wallets ─────────────────────────────
  Future<List<WalletAddress>> list() async {
    final res = await _client.get(
      WalletHttp.uri(WalletEndpoints.list()),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);

    final data = WalletHttp.decodeJson<dynamic>(res);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(WalletAddress.fromJson)
          .toList();
    }
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'wallets', 'list'],
    );
    if (items.isNotEmpty) {
      return items.map(WalletAddress.fromJson).toList();
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /wallets',
      body: res.body,
    );
  }

  /// ── POST /wallets ────────────────────────────
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

  /// ── PATCH /wallets/:id ───────────────────────
  Future<WalletAddress> updateLabel(String id, {required String label}) async {
    final res = await _client.patch(
      WalletHttp.uri(WalletEndpoints.update(id)),
      headers: await _headers(),
      body: jsonEncode(UpdateWalletRequest(label: label).toJson()),
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

  /// ── DELETE /wallets/:id ──────────────────────
  Future<void> remove(String id) async {
    final res = await _client.delete(
      WalletHttp.uri(WalletEndpoints.remove(id)),
      headers: await _headers(),
    );

    WalletHttp.ensureOk(res);
  }
}
