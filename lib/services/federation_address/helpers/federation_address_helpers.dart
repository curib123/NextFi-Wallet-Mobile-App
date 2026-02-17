import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

import 'federation_address_exceptions.dart';

class FederationAddressHttp {
  static final Uri _baseUri = Uri.parse(cetralized_baseUrl);
  static final String _publicBase =
      '${_baseUri.scheme}://${_baseUri.authority}';

  static Uri uri(String path, {Map<String, String>? queryParams}) {
    return Uri.parse('$cetralized_baseUrl$path').replace(
      queryParameters: queryParams?.isEmpty == true ? null : queryParams,
    );
  }

  static Uri publicUri(String path, {Map<String, String>? queryParams}) {
    return Uri.parse('$_publicBase$path').replace(
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
