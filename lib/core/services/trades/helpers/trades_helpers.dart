import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/base_url/base_url.dart';

import 'trades_exceptions.dart';

class TradesHttp {
  static Uri uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse('$centralizedBaseUrl$path');
    if (queryParams == null || queryParams.isEmpty) return base;
    final merged = <String, String>{...base.queryParameters, ...queryParams};
    return base.replace(queryParameters: merged);
  }

  static T decodeJson<T>(http.Response res) {
    if (res.body.isEmpty) return {} as T;
    return jsonDecode(res.body) as T;
  }

  static void ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String? msg;
    try {
      final body = jsonDecode(res.body);
      final message = body['message'];
      if (message is List && message.isNotEmpty) {
        msg = message.first.toString();
      } else {
        msg = message?.toString() ?? body['error']?.toString();
      }
    } catch (_) {}
    throw TradeApiException(
      res.statusCode,
      msg ?? 'Request failed',
      body: res.body.isEmpty ? null : res.body,
    );
  }
}
