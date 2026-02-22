import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

import 'offers_exceptions.dart';

class OffersHttp {
  static Uri uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse('$centralized_baseUrl$path');
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
    throw ApiException(
      res.statusCode,
      'Request failed',
      body: res.body.isEmpty ? null : res.body,
    );
  }
}
