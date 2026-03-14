import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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
  final Map<String, (String key, DateTime at)> _idempotencyScopeCache = {};

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'trade',
    'trades',
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

  String _idempotencyForScope(String scope) {
    final now = DateTime.now();
    final cached = _idempotencyScopeCache[scope];
    if (cached != null && now.difference(cached.$2).inMinutes < 3) {
      return cached.$1;
    }
    final key = const Uuid().v4();
    _idempotencyScopeCache[scope] = (key, now);
    return key;
  }

  Future<Map<String, String>> _headers({String? idempotencyScope}) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw TradeApiException(401, 'Missing auth token');
    }
    final h = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (idempotencyScope != null && idempotencyScope.trim().isNotEmpty) {
      h['x-idempotency-key'] = _idempotencyForScope(idempotencyScope.trim());
    }
    return h;
  }

  bool _isEnvelope(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k));

  Map<String, dynamic>? _extractMap(dynamic data, {int depth = 0}) {
    if (depth > 6 || data == null) return null;
    if (data is List) {
      for (final item in data) {
        final r = _extractMap(item, depth: depth + 1);
        if (r != null) return r;
      }
      return null;
    }
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.isEmpty) return null;

    for (final key in const ['data', 'item', 'trade']) {
      if (!map.containsKey(key)) continue;
      final r = _extractMap(map[key], depth: depth + 1);
      if (r != null) return r;
    }
    if (!_isEnvelope(map)) return map;
    for (final v in map.values) {
      final r = _extractMap(v, depth: depth + 1);
      if (r != null) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractList(dynamic data, {int depth = 0}) {
    if (depth > 6 || data == null) return const [];
    if (data is List) {
      final direct = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (direct.isNotEmpty) return direct;
      for (final item in data) {
        final r = _extractList(item, depth: depth + 1);
        if (r.isNotEmpty) return r;
      }
      return const [];
    }
    if (data is! Map) return const [];
    final map = Map<String, dynamic>.from(data);
    for (final key in const ['items', 'data', 'trades', 'list']) {
      final v = map[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    for (final v in map.values) {
      final r = _extractList(v, depth: depth + 1);
      if (r.isNotEmpty) return r;
    }
    return const [];
  }

  TradesPagedMeta _extractMeta(dynamic data, {required int fallbackCount}) {
    if (data is Map<String, dynamic>) {
      final m = data['meta'] ?? data['pagination'];
      if (m is Map<String, dynamic>) return TradesPagedMeta.fromJson(m);
      if (data.containsKey('page') || data.containsKey('total')) {
        return TradesPagedMeta.fromJson(data);
      }
    }
    return TradesPagedMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  String _extractString(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text;
  }

  String _extractUploadedFileUrl(dynamic data, {int depth = 0}) {
    if (data == null || depth > 8) return '';
    if (data is String) {
      final raw = data.trim();
      if (raw.isEmpty) return '';
      if (raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('/')) {
        return raw;
      }
      return '';
    }
    if (data is List) {
      for (final item in data) {
        final found = _extractUploadedFileUrl(item, depth: depth + 1);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    if (data is! Map) return '';

    final map = Map<String, dynamic>.from(data);
    for (final key in const [
      'fileUrl',
      'file_url',
      'url',
      'proofUrl',
      'proof_url',
      'imageUrl',
      'image_url',
      'attachmentUrl',
      'attachment_url',
      'location',
      'path',
    ]) {
      final candidate = _extractString(map[key]);
      final found = _extractUploadedFileUrl(candidate, depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
    for (final key in const [
      'proofUrls',
      'proof_urls',
      'fileUrls',
      'file_urls',
      'images',
      'attachments',
      'files',
      'proofs',
      'data',
      'item',
      'result',
      'payload',
    ]) {
      final found = _extractUploadedFileUrl(map[key], depth: depth + 1);
      if (found.isNotEmpty) return found;
    }
    return '';
  }

  // ── User routes ─────────────────────────────────────────────────────────────

  Future<TradeModel> create(CreateTradeRequest req) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.create()),
      headers: await _headers(
        idempotencyScope:
            'create:${req.offerId}:${req.userPaymentAccountId}:${req.cryptoAmount}:${req.fiatAmount}:${req.cryptoReceiverAddress ?? ''}',
      ),
      body: jsonEncode(req.toJson()),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for POST /trades',
      body: res.body,
    );
  }

  Future<TradesPagedResponse> listPaged({
    TradesListQuery query = const TradesListQuery(),
  }) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.list(), queryParams: query.toQueryMap()),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final items = _extractList(data).map(TradeModel.fromJson).toList();
    return TradesPagedResponse(
      items: items,
      meta: _extractMeta(data, fallbackCount: items.length),
    );
  }

  Future<TradeModel> getOne(String id) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.getOne(id)),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for GET /trades/$id',
    );
  }

  Future<TradeModel> markFiatSent(String id) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.markFiatSent(id)),
      headers: await _headers(idempotencyScope: 'mark-fiat-sent:$id'),
      body: jsonEncode({}),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for mark-fiat-sent',
    );
  }

  Future<TradeModel> confirmRequest(String id) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.confirmRequest(id)),
      headers: await _headers(idempotencyScope: 'confirm-request:$id'),
      body: jsonEncode({}),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for confirm-request',
    );
  }

  Future<TradeModel> confirmFiat(String id, {String? fiatRefNo}) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.confirmFiat(id)),
      headers: await _headers(
        idempotencyScope: 'confirm-fiat:$id:${fiatRefNo ?? ''}',
      ),
      body: jsonEncode(ConfirmFiatRequest(fiatRefNo: fiatRefNo).toJson()),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for confirm-fiat',
    );
  }

  Future<TradeModel> cancelTrade(String id, {String? reason}) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.cancel(id)),
      headers: await _headers(idempotencyScope: 'cancel:$id:${reason ?? ''}'),
      body: jsonEncode(CancelTradeRequest(reason: reason).toJson()),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(res.statusCode, 'Unexpected response for cancel');
  }

  // ── Crypto escrow operations ─────────────────────────────────────────────────

  /// Lock crypto into escrow (Step B in both SELL and BUY flows)
  /// - SELL offer: merchant locks crypto
  /// - BUY offer: buyer locks crypto
  Future<TradeModel> lockCrypto(
    String id, {
    required String claimableBalanceId,
    required String createTxHash,
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.lockCrypto(id)),
      headers: await _headers(
        idempotencyScope: 'lock-crypto:$id:$claimableBalanceId:$createTxHash',
      ),
      body: jsonEncode(
        LockCryptoRequest(
          claimableBalanceId: claimableBalanceId,
          createTxHash: createTxHash,
        ).toJson(),
      ),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for lock-crypto',
    );
  }

  /// Claim crypto from escrow (Step E in both flows)
  /// - SELL offer: buyer claims crypto
  /// - BUY offer: merchant claims crypto
  Future<TradeModel> claimCrypto(
    String id, {
    required String claimTxHash,
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.claimCrypto(id)),
      headers: await _headers(
        idempotencyScope: 'claim-crypto:$id:$claimTxHash',
      ),
      body: jsonEncode(ClaimCryptoRequest(claimTxHash: claimTxHash).toJson()),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for claim-crypto',
    );
  }

  /// Refund crypto from expired escrow (only original locker can call)
  Future<TradeModel> refundCrypto(
    String id, {
    required String refundTxHash,
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.refundCrypto(id)),
      headers: await _headers(
        idempotencyScope: 'refund-crypto:$id:$refundTxHash',
      ),
      body: jsonEncode(
        RefundCryptoRequest(refundTxHash: refundTxHash).toJson(),
      ),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for refund-crypto',
    );
  }

  // ── Mark Fiat Sent with proof ─────────────────────────────────────────────

  Future<TradeModel> markFiatSentWithProof(
    String id, {
    String? note,
    List<String>? proofUrls,
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.markFiatSent(id)),
      headers: await _headers(
        idempotencyScope:
            'mark-fiat-sent-proof:$id:${note ?? ''}:${proofUrls?.join(',') ?? ''}',
      ),
      body: jsonEncode(
        MarkFiatSentRequest(note: note, proofUrls: proofUrls).toJson(),
      ),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for mark-fiat-sent',
    );
  }

  // ── Dispute ───────────────────────────────────────────────────────────────

  Future<TradeModel> openDispute(
    String id, {
    required String reason,
    String? details,
    String? description,
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.disputes()),
      headers: await _headers(
        idempotencyScope:
            'open-dispute:$id:$reason:${details ?? description ?? ''}',
      ),
      body: jsonEncode(
        OpenDisputeRequest(
          tradeId: id,
          reason: reason,
          details: (details ?? description)?.trim(),
        ).toJson(),
      ),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return TradeModel.fromJson(map);
    throw TradeApiException(
      res.statusCode,
      'Unexpected response for open-dispute',
    );
  }

  // ── Messages ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTradeMessages(String id) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.messages(id)),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    final items = _extractList(data);
    return items;
  }

  Future<void> sendTradeMessage(
    String id, {
    required String ciphertext,
    required String algorithm,
    required String senderKeyId,
    required String nonce,
    String kind = 'TEXT',
  }) async {
    final res = await _client.post(
      TradesHttp.uri(TradesEndpoints.messages(id)),
      headers: await _headers(),
      body: jsonEncode({
        'kind': kind,
        'ciphertext': ciphertext,
        'algorithm': algorithm,
        'senderKeyId': senderKeyId,
        'nonce': nonce,
      }),
    );
    TradesHttp.ensureOk(res);
  }

  // ── Payment proof upload (multipart) ─────────────────────────────────────

  Future<String?> uploadPaymentProof(
    String id, {
    required File file,
    String type = 'FIAT',
    String? note,
    String? referenceNo,
    String? txHash,
  }) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw TradeApiException(401, 'Missing auth token');
    }
    final uri = TradesHttp.uri(TradesEndpoints.proofs(id));
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['x-idempotency-key'] = _idempotencyForScope(
        'upload-proof:$id:${file.path}:${file.lengthSync()}',
      )
      ..fields['type'] = type.toUpperCase();
    final normalizedType = type.trim().toUpperCase();
    if (normalizedType == 'CRYPTO') {
      final hash = (txHash ?? '').trim();
      if (hash.isEmpty) {
        throw TradeApiException(
          400,
          'txHash is required when uploading CRYPTO proof',
        );
      }
      request.fields['txHash'] = hash;
    }
    if (note != null && note.isNotEmpty) request.fields['note'] = note;
    if (referenceNo != null && referenceNo.isNotEmpty) {
      request.fields['referenceNo'] = referenceNo;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    TradesHttp.ensureOk(res);
    dynamic data;
    try {
      data = TradesHttp.decodeJson<dynamic>(res);
    } catch (_) {
      data = null;
    }
    final proofUrl = _extractUploadedFileUrl(data);
    return proofUrl.isEmpty ? null : proofUrl;
  }

  Future<List<Map<String, dynamic>>> getTradeProofs(String id) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.proofs(id)),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    return _extractList(data);
  }

  Future<List<Map<String, dynamic>>> getDisputeEvidence(
    String disputeId,
  ) async {
    final res = await _client.get(
      TradesHttp.uri(TradesEndpoints.disputeEvidence(disputeId)),
      headers: await _headers(),
    );
    TradesHttp.ensureOk(res);
    final data = TradesHttp.decodeJson<dynamic>(res);
    return _extractList(data);
  }

  Future<void> uploadDisputeEvidence(
    String disputeId, {
    required File file,
    String? note,
  }) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw TradeApiException(401, 'Missing auth token');
    }
    final uri = TradesHttp.uri(TradesEndpoints.disputeEvidence(disputeId));
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['x-idempotency-key'] = _idempotencyForScope(
        'upload-dispute-evidence:$disputeId:${file.path}:${file.lengthSync()}',
      );
    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    TradesHttp.ensureOk(res);
  }

  void dispose() => _client.close();
}
