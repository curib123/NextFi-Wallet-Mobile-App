import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

import 'profile_exceptions.dart';

class ProfileHttp {
  static Uri uri(String path) => Uri.parse('$centralized_baseUrl$path');

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
