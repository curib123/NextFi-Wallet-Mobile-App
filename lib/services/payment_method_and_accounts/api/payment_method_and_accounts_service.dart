import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../base_url/base_url.dart';
import '../models/payment_method_and_accounts_dtos.dart';
import '../models/payment_method_and_accounts_models.dart';
import 'payment_method_and_accounts_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class PaymentMethodAndAccountsService {
  PaymentMethodAndAccountsService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Uri _uri(String path, {Map<String, String>? queryParams}) {
    final base = cetralized_baseUrl.endsWith('/')
        ? cetralized_baseUrl.substring(0, cetralized_baseUrl.length - 1)
        : cetralized_baseUrl;

    final uri = Uri.parse('$base$path');
    if (queryParams == null || queryParams.isEmpty) return uri;

    return uri.replace(queryParameters: queryParams);
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw Exception('Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  void _ensureOk(http.Response res, String op) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('$op failed (${res.statusCode}): ${res.body}');
  }

  Future<List<PaymentMethodModel>> listPaymentMethods(
    PaymentMethodsQuery query,
  ) async {
    final res = await _client.get(
      _uri(
        PaymentMethodAndAccountsEndpoints.paymentMethods(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /payment-methods');
    final data = _decode(res);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<PaymentMethodModel> getPaymentMethodById(String id) async {
    final res = await _client.get(
      _uri(PaymentMethodAndAccountsEndpoints.paymentMethodById(id)),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /payment-methods/:id');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return PaymentMethodModel.fromJson(data);
    }

    throw Exception('Unexpected response for GET /payment-methods/$id');
  }

  Future<List<UserPaymentAccountModel>> listMyPaymentAccounts(
    PaymentAccountsQuery query,
  ) async {
    final res = await _client.get(
      _uri(
        PaymentMethodAndAccountsEndpoints.paymentAccounts(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /payment-accounts');
    final data = _decode(res);

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(UserPaymentAccountModel.fromJson)
          .toList();
    }

    return const [];
  }

  Future<UserPaymentAccountModel> getMyPaymentAccountById(String id) async {
    final res = await _client.get(
      _uri(PaymentMethodAndAccountsEndpoints.paymentAccountById(id)),
      headers: await _headers(),
    );

    _ensureOk(res, 'GET /payment-accounts/:id');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw Exception('Unexpected response for GET /payment-accounts/$id');
  }

  Future<UserPaymentAccountModel> createMyPaymentAccount(
    CreateUserPaymentAccountRequest req,
  ) async {
    final res = await _client.post(
      _uri(PaymentMethodAndAccountsEndpoints.paymentAccounts()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    _ensureOk(res, 'POST /payment-accounts');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw Exception('Unexpected response for POST /payment-accounts');
  }

  Future<UserPaymentAccountModel> updateMyPaymentAccount(
    String id,
    UpdateUserPaymentAccountRequest req,
  ) async {
    final res = await _client.patch(
      _uri(PaymentMethodAndAccountsEndpoints.paymentAccountById(id)),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    _ensureOk(res, 'PATCH /payment-accounts/:id');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw Exception('Unexpected response for PATCH /payment-accounts/$id');
  }

  Future<UserPaymentAccountModel> toggleMyPaymentAccount(String id) async {
    final res = await _client.patch(
      _uri(PaymentMethodAndAccountsEndpoints.togglePaymentAccount(id)),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{}),
    );

    _ensureOk(res, 'PATCH /payment-accounts/:id/toggle');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw Exception('Unexpected response for PATCH /payment-accounts/$id/toggle');
  }

  Future<bool> deleteMyPaymentAccount(String id) async {
    final res = await _client.delete(
      _uri(PaymentMethodAndAccountsEndpoints.paymentAccountById(id)),
      headers: await _headers(),
    );

    _ensureOk(res, 'DELETE /payment-accounts/:id');
    final data = _decode(res);

    if (data is Map<String, dynamic>) {
      return data['success'] == true;
    }

    return true;
  }
}
