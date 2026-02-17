import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/payment_method_and_accounts_exceptions.dart';
import '../helpers/payment_method_and_accounts_helpers.dart';
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

  Future<List<PaymentMethodModel>> listPaymentMethods(
    PaymentMethodsQuery query,
  ) async {
    final res = await _client.get(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentMethods(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

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
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentMethodById(id),
      ),
      headers: await _headers(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return PaymentMethodModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /payment-methods/$id',
      body: res.body,
    );
  }

  Future<List<UserPaymentAccountModel>> listMyPaymentAccounts(
    PaymentAccountsQuery query,
  ) async {
    final res = await _client.get(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccounts(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

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
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccountById(id),
      ),
      headers: await _headers(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /payment-accounts/$id',
      body: res.body,
    );
  }

  Future<UserPaymentAccountModel> createMyPaymentAccount(
    CreateUserPaymentAccountRequest req,
  ) async {
    final res = await _client.post(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccounts(),
      ),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /payment-accounts',
      body: res.body,
    );
  }

  Future<UserPaymentAccountModel> updateMyPaymentAccount(
    String id,
    UpdateUserPaymentAccountRequest req,
  ) async {
    final res = await _client.patch(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccountById(id),
      ),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /payment-accounts/$id',
      body: res.body,
    );
  }

  Future<UserPaymentAccountModel> toggleMyPaymentAccount(String id) async {
    final res = await _client.patch(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.togglePaymentAccount(id),
      ),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{}),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return UserPaymentAccountModel.fromJson(data);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /payment-accounts/$id/toggle',
      body: res.body,
    );
  }

  Future<bool> deleteMyPaymentAccount(String id) async {
    final res = await _client.delete(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccountById(id),
      ),
      headers: await _headers(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);

    if (data is Map<String, dynamic>) {
      return data['success'] == true;
    }

    return true;
  }
}
