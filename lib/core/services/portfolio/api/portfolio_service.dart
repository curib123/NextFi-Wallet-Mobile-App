import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:next_fi/core/services/base_url/base_url.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_dtos.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';

typedef PortfolioTokenProvider = Future<String?> Function();

class PortfolioService {
  PortfolioService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final PortfolioTokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw Exception('Missing JWT token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(centralizedBaseUrl);
    return base.replace(
      path:
          '${base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path}$path',
      queryParameters: query,
    );
  }

  Future<WalletPortfolioData> getWalletPortfolio({
    required String walletId,
    required PortfolioRange range,
  }) async {
    final response = await _client.get(
      _uri('/portfolio/wallets/$walletId', {'range': portfolioRangeToApi(range)}),
      headers: await _headers(),
    );
    _ensureOk(response);
    return WalletPortfolioData.fromJson(_decodeMap(response.body));
  }

  Future<void> createSnapshot(CreatePortfolioSnapshotRequest request) async {
    final response = await _client.post(
      _uri('/portfolio/snapshots'),
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'Portfolio API error ${response.statusCode}: ${response.body}',
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body.isEmpty ? '{}' : body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw Exception('Unexpected portfolio response shape');
  }

  void dispose() {
    _client.close();
  }
}
