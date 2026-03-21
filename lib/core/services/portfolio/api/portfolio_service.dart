import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/base_url/base_url.dart';
import 'package:next_fi/core/services/wallet/helpers/wallet_exceptions.dart';
import 'package:next_fi/core/services/portfolio/api/portfolio_endpoints.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';

typedef PortfolioTokenProvider = Future<String?> Function();

class PortfolioService {
  PortfolioService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final PortfolioTokenProvider tokenProvider;
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

  Uri _uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse(centralizedBaseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: queryParams,
    );
  }

  Future<void> createSnapshot(CreatePortfolioSnapshotRequest request) async {
    final response = await _client.post(
      _uri(PortfolioEndpoints.createSnapshot()),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    _ensureOk(response);
  }

  Future<WalletPortfolioData> getWalletPortfolio({
    required String walletId,
    required PortfolioRange range,
  }) async {
    final response = await _client.get(
      _uri(
        PortfolioEndpoints.wallet(walletId),
        queryParams: {'range': portfolioRangeToApi(range)},
      ),
      headers: await _headers(),
    );
    _ensureOk(response);
    final decoded = _decodeJson(response);
    final map = _extractMap(decoded, keys: const ['data', 'portfolio']);
    if (map == null) {
      throw ApiException(
        response.statusCode,
        'Unexpected response for wallet portfolio',
        body: response.body,
      );
    }
    return WalletPortfolioData.fromJson(map);
  }

  Map<String, dynamic>? _extractMap(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8 || data == null) return null;
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final nested = _extractMap(data[key], keys: keys, depth: depth + 1);
        if (nested != null) return nested;
      }
      return data;
    }
    if (data is Map) {
      return _extractMap(
        data.map((key, value) => MapEntry(key.toString(), value)),
        keys: keys,
        depth: depth,
      );
    }
    return null;
  }

  dynamic _decodeJson(http.Response response) {
    if (response.body.trim().isEmpty) return const <String, dynamic>{};
    return jsonDecode(response.body);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(
      response.statusCode,
      'Portfolio request failed',
      body: response.body,
    );
  }

  void dispose() {
    _client.close();
  }
}
