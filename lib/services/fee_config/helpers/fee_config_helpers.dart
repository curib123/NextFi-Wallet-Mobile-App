import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

import 'fee_config_exceptions.dart';

class FeeConfigHttp {
  static Uri uri(String path, {Map<String, String>? queryParams}) {
    return Uri.parse('$centralized_baseUrl$path').replace(
      queryParameters: queryParams?.isEmpty == true ? null : queryParams,
    );
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
