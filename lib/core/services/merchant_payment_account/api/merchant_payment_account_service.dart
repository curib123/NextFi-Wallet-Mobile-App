import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/merchant_payment_account_exceptions.dart';
import '../helpers/merchant_payment_account_helpers.dart';
import '../models/merchant_payment_account_dtos.dart';
import '../models/merchant_payment_account_models.dart';
import 'merchant_payment_account_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class MerchantPaymentAccountService {
  MerchantPaymentAccountService({
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

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
      for (final key in const [
        'data',
        'account',
        'merchantPaymentAccount',
        'merchant_payment_account',
      ]) {
        final v = data[key];
        if (v is Map<String, dynamic>) return v;
      }
      final envelopeOnly = {'data', 'success', 'message', 'error', 'meta'};
      if (!data.keys.every((k) => envelopeOnly.contains(k))) return data;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractListMaps(dynamic data) {
    if (data == null) return const [];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      for (final key in const ['items', 'data', 'accounts']) {
        final v = data[key];
        if (v is List) {
          return v.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return const [];
  }

  MerchantPaymentAccountMeta _extractMeta(
    dynamic data, {
    required int fallbackCount,
  }) {
    if (data is Map<String, dynamic>) {
      final metaRaw = data['meta'] ?? data['pagination'];
      if (metaRaw is Map<String, dynamic>) {
        return MerchantPaymentAccountMeta.fromJson(metaRaw);
      }
    }
    return MerchantPaymentAccountMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount,
      totalPages: 1,
    );
  }

  Future<MerchantPaymentAccountPagedResponse> listPaged({
    MerchantPaymentAccountListQuery query =
        const MerchantPaymentAccountListQuery(),
  }) async {
    final res = await _client.get(
      MerchantPaymentAccountHttp.uri(
        MerchantPaymentAccountEndpoints.list(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    final data = MerchantPaymentAccountHttp.decodeJson<dynamic>(res);
    final maps = _extractListMaps(data);
    final meta = _extractMeta(data, fallbackCount: maps.length);
    return MerchantPaymentAccountPagedResponse(
      items: maps.map(MerchantPaymentAccountModel.fromJson).toList(),
      meta: meta,
    );
  }

  Future<MerchantPaymentAccountModel> getOne(String id) async {
    final res = await _client.get(
      MerchantPaymentAccountHttp.uri(
        MerchantPaymentAccountEndpoints.getOne(id),
      ),
      headers: await _headers(),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    final data = MerchantPaymentAccountHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantPaymentAccountModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /merchant-payment-accounts/$id',
      body: res.body,
    );
  }

  Future<MerchantPaymentAccountModel> create(
    CreateMerchantPaymentAccountRequest req,
  ) async {
    final res = await _client.post(
      MerchantPaymentAccountHttp.uri(MerchantPaymentAccountEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    final data = MerchantPaymentAccountHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantPaymentAccountModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /merchant-payment-accounts',
      body: res.body,
    );
  }

  Future<MerchantPaymentAccountModel> update(
    String id,
    UpdateMerchantPaymentAccountRequest req,
  ) async {
    final res = await _client.patch(
      MerchantPaymentAccountHttp.uri(
        MerchantPaymentAccountEndpoints.update(id),
      ),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    final data = MerchantPaymentAccountHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantPaymentAccountModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /merchant-payment-accounts/$id',
      body: res.body,
    );
  }

  Future<MerchantPaymentAccountModel> toggle(String id) async {
    final res = await _client.patch(
      MerchantPaymentAccountHttp.uri(
        MerchantPaymentAccountEndpoints.toggle(id),
      ),
      headers: await _headers(),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    final data = MerchantPaymentAccountHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);
    if (map != null) return MerchantPaymentAccountModel.fromJson(map);
    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /merchant-payment-accounts/$id/toggle',
      body: res.body,
    );
  }

  Future<bool> remove(String id) async {
    final res = await _client.delete(
      MerchantPaymentAccountHttp.uri(
        MerchantPaymentAccountEndpoints.remove(id),
      ),
      headers: await _headers(),
    );
    MerchantPaymentAccountHttp.ensureOk(res);
    return true;
  }

  void dispose() => _client.close();
}
