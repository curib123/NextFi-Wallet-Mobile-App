import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/base_url/base_url.dart';

import 'trade_payment_accounts_exceptions.dart';

class TradePaymentAccountsHttp {
  static Uri uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse(centralizedBaseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${base.path}$path'.replaceAll('//', '/'),
      queryParameters: queryParams == null || queryParams.isEmpty
          ? null
          : queryParams,
    );
  }

  static dynamic decodeJson(http.Response res) {
    final body = res.body.trim();
    if (body.isEmpty) return null;
    return jsonDecode(body);
  }

  static void ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final dynamic parsed = decodeJson(res);
    String message = 'Request failed';
    if (parsed is Map<String, dynamic>) {
      message = (parsed['message'] ?? parsed['error'] ?? message).toString();
    }
    throw TradePaymentAccountsApiException(
      res.statusCode,
      message,
      body: res.body,
    );
  }
}
