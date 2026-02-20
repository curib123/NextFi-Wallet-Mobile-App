import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../helpers/trades_exceptions.dart';
import '../helpers/trades_helpers.dart';
import '../models/trades_dtos.dart';
import '../models/trades_models.dart';
import 'trades_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class TradesService {
  TradesService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  static const Set<String> _allowedImageExt = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'trade',
    'trades',
    'message',
    'messages',
    'meta',
    'pagination',
    'page',
    'limit',
    'total',
    'totalPages',
    'success',
    'ok',
    'status',
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

  // ── Trade CRUD ────────────────────────────────────────────────────────────

  Future<TradeModel> createTrade(CreateTradeRequest req) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.createTrade()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /trades',
      body: res.body,
    );
  }

  Future<List<TradeModel>> listMyTrades(TradesQuery query) async {
    final res = await _client.get(
      TradesHttp.uri(
        TradesEndpoints.listMyTrades(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'trades', 'list'],
    );
    return items.map(TradeModel.fromJson).toList();
  }

  Future<TradeModel> getMyTradeById(String id) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.getMyTrade(id)),
      headers: await _headers(),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /trades/me/$id',
      body: res.body,
    );
  }

  // ── vF1 Action methods ────────────────────────────────────────────────────

  Future<TradeModel> _postAction(
    String url,
    Map<String, dynamic> body,
    String label,
  ) async {
    final res = await _client.post(
      TradesHttp.uri(url),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);
    throw ApiException(res.statusCode, 'Unexpected response for $label', body: res.body);
  }

  /// SELL: user marks fiat as sent.
  Future<TradeModel> fiatSent(String id, {String? note}) =>
      _postAction(
        TradesEndpoints.fiatSent(id),
        FiatSentRequest(note: note).toJson(),
        'POST /trades/$id/actions/fiat-sent',
      );

  /// SELL: merchant confirms fiat received.
  Future<TradeModel> fiatReceived(String id) =>
      _postAction(
        TradesEndpoints.fiatReceived(id),
        const FiatReceivedRequest().toJson(),
        'POST /trades/$id/actions/fiat-received',
      );

  /// BUY: merchant marks fiat as sent to user.
  Future<TradeModel> fiatSentMerchant(String id, {String? note}) =>
      _postAction(
        TradesEndpoints.fiatSentMerchant(id),
        FiatSentMerchantRequest(note: note).toJson(),
        'POST /trades/$id/actions/fiat-sent-merchant',
      );

  /// BUY: user confirms fiat received from merchant.
  Future<TradeModel> confirmReceived(String id) =>
      _postAction(
        TradesEndpoints.confirmReceived(id),
        const ConfirmReceivedRequest().toJson(),
        'POST /trades/$id/actions/confirm-received',
      );

  /// Either party cancels the trade.
  Future<TradeModel> cancelTradeAction(String id, {String? reason}) =>
      _postAction(
        TradesEndpoints.cancelTradeAction(id),
        CancelTradeActionRequest(reason: reason).toJson(),
        'POST /trades/$id/actions/cancel',
      );

  /// Either party opens a dispute.
  Future<TradeModel> openDisputeAction(String id, {required String reason}) =>
      _postAction(
        TradesEndpoints.openDisputeAction(id),
        OpenDisputeActionRequest(reason: reason).toJson(),
        'POST /trades/$id/actions/open-dispute',
      );

  // ── vF1 Trade chat ────────────────────────────────────────────────────────

  Future<List<TradeMessageModel>> getTradeChat(
    String id, {
    int page = 1,
  }) async {
    final res = await _client.get(
      TradesHttp.uri(
        TradesEndpoints.getTradeChat(id),
        queryParams: {'page': '$page'},
      ),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['messages', 'items', 'data'],
    );
    return items.map(TradeMessageModel.fromJson).toList();
  }

  Future<TradeMessageModel> sendTradeChatMessage(
    String id,
    String message,
  ) async {
    final req = SendTradeChatRequest(message: message);
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.sendTradeChatMessage(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(
      data,
      keys: const ['data', 'message', 'tradeMessage', 'item'],
    );
    if (map != null) return TradeMessageModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /trades/$id/chat/messages',
      body: res.body,
    );
  }

  // ── Upload proof ──────────────────────────────────────────────────────────

  Future<TradeModel> uploadPaymentProof(
    String tradeId, {
    required File image,
    String? note,
  }) async {
    _ensureImagePathAllowed(image.path, label: 'Payment proof');
    final token = await _tokenOrThrow();

    final req =
        http.MultipartRequest(
            'POST',
            TradesHttp.uri(TradesEndpoints.uploadProof(tradeId)),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..files.add(await http.MultipartFile.fromPath('image', image.path));

    if (note != null && note.trim().isNotEmpty) {
      req.fields['note'] = note.trim();
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /trades/me/$tradeId/proof',
      body: res.body,
    );
  }

  // ── Seller (merchant) routes ──────────────────────────────────────────────

  Future<List<TradeModel>> listSellerTrades(TradesQuery query) async {
    final res = await _client.get(
      TradesHttp.uri(
        TradesEndpoints.listSellerTrades(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'trades', 'list'],
    );
    return items.map(TradeModel.fromJson).toList();
  }

  Future<TradeModel> getSellerTradeById(String id) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.getSellerTrade(id)),
      headers: await _headers(),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /trades/seller/me/$id',
      body: res.body,
    );
  }

  // ── Legacy methods (kept for backward compat) ─────────────────────────────

  Future<TradeModel> markPaid(
    String id, {
    required String idempotencyKey,
  }) async {
    final req = MarkPaidTradeRequest(idempotencyKey: idempotencyKey);
    final res = await _client.patch(
      TradesHttp.uri(TradesEndpoints.markPaid(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /trades/me/$id/paid',
      body: res.body,
    );
  }

  Future<TradeModel> cancelMyTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
    String? reason,
  }) async {
    final req = CancelTradeRequest(
      idempotencyKey: idempotencyKey,
      txHash: txHash,
      reason: reason,
    );
    final res = await _client.patch(
      TradesHttp.uri(TradesEndpoints.cancelMyTrade(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /trades/me/$id/cancel',
      body: res.body,
    );
  }

  Future<TradeMessageModel> sendMyMessage(
    String tradeId,
    String message,
  ) async {
    final req = SendTradeMessageRequest(message: message);
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.sendMyMessage(tradeId)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(
      data,
      keys: const ['data', 'message', 'tradeMessage', 'item'],
    );
    if (map != null) return TradeMessageModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /trades/me/$tradeId/messages',
      body: res.body,
    );
  }

  Future<TradeModel> releaseSellerTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
  }) async {
    final req = ReleaseTradeRequest(
      idempotencyKey: idempotencyKey,
      txHash: txHash,
    );
    final res = await _client.patch(
      TradesHttp.uri(TradesEndpoints.releaseSellerTrade(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /trades/seller/me/$id/release',
      body: res.body,
    );
  }

  Future<TradeModel> cancelSellerTrade(
    String id, {
    required String idempotencyKey,
    String? txHash,
    String? reason,
  }) async {
    final req = CancelTradeRequest(
      idempotencyKey: idempotencyKey,
      txHash: txHash,
      reason: reason,
    );
    final res = await _client.patch(
      TradesHttp.uri(TradesEndpoints.cancelSellerTrade(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'trade', 'item']);
    if (map != null) return TradeModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /trades/seller/me/$id/cancel',
      body: res.body,
    );
  }
}
