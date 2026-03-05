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
  }) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
      for (final key in keys) {
        final wrapped = data[key];
        if (wrapped is Map<String, dynamic>) return wrapped;
      }
      if (keys.isNotEmpty &&
          data.length == 1 &&
          keys.contains(data.keys.first) &&
          data.values.first == null) {
        return null;
      }
      return data;
    }
    return null;
  }

  List<dynamic> _extractList(dynamic data, {List<String> keys = const []}) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final wrapped = data[key];
        if (wrapped is List) return wrapped;
      }
    }
    return const [];
  }

  Future<List<PaymentMethodModel>> listPaymentMethods(
    PaymentMethodsQuery query,
  ) async {
    final res = await _client.get(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentMethods(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _publicHeaders(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);
    final list = _extractList(
      data,
      keys: const ['data', 'items', 'paymentMethods'],
    );

    return list
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodModel.fromJson)
        .toList();
  }

  Future<PaymentMethodModel> getPaymentMethodById(String id) async {
    final res = await _client.get(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentMethodById(id),
      ),
      headers: await _publicHeaders(),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'paymentMethod']);

    if (map != null) {
      return PaymentMethodModel.fromJson(map);
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
    final list = _extractList(
      data,
      keys: const ['data', 'items', 'paymentAccounts'],
    );

    return list
        .whereType<Map<String, dynamic>>()
        .map(UserPaymentAccountModel.fromJson)
        .toList();
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
    final map = _extractMap(data, keys: const ['data', 'paymentAccount']);

    if (map != null) {
      return UserPaymentAccountModel.fromJson(map);
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
    final map = _extractMap(data, keys: const ['data', 'paymentAccount']);

    if (map != null) {
      return UserPaymentAccountModel.fromJson(map);
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
    final map = _extractMap(data, keys: const ['data', 'paymentAccount']);

    if (map != null) {
      return UserPaymentAccountModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /payment-accounts/$id',
      body: res.body,
    );
  }

  Future<UserPaymentAccountModel> editMyPaymentAccount(
    String id,
    UpdateUserPaymentAccountRequest req,
  ) async {
    final res = await _client.put(
      PaymentMethodAndAccountsHttp.uri(
        PaymentMethodAndAccountsEndpoints.paymentAccountById(id),
      ),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    PaymentMethodAndAccountsHttp.ensureOk(res);
    final data = PaymentMethodAndAccountsHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'paymentAccount']);

    if (map != null) {
      return UserPaymentAccountModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PUT /payment-accounts/$id',
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
    final map = _extractMap(data, keys: const ['data', 'paymentAccount']);

    if (map != null) {
      return UserPaymentAccountModel.fromJson(map);
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
      final wrapped = data['data'];
      if (wrapped is Map<String, dynamic>) {
        return wrapped['success'] == true;
      }
      return data['success'] == true;
    }

    return true;
  }
}
