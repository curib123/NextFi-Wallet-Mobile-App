import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/fee_config_exceptions.dart';
import '../helpers/fee_config_helpers.dart';
import '../models/fee_config_dtos.dart';
import '../models/fee_config_models.dart';
import 'fee_config_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class FeeConfigService {
  FeeConfigService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _publicHeaders() async {
    return const {'Content-Type': 'application/json'};
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

  Future<FeeConfigModel> getCurrent() async {
    final res = await _client.get(
      FeeConfigHttp.uri(FeeConfigEndpoints.current()),
      headers: await _publicHeaders(),
    );

    FeeConfigHttp.ensureOk(res);
    final data = FeeConfigHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'feeConfig']);

    if (map != null) {
      return FeeConfigModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for GET /fee-config',
      body: res.body,
    );
  }

  Future<FeeConfigModel> patch(UpdateFeeConfigRequest req) async {
    final res = await _client.patch(
      FeeConfigHttp.uri(FeeConfigEndpoints.current()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    FeeConfigHttp.ensureOk(res);
    final data = FeeConfigHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'feeConfig']);

    if (map != null) {
      return FeeConfigModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for PATCH /fee-config',
      body: res.body,
    );
  }
}
