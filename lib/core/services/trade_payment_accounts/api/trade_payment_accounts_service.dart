import 'package:http/http.dart' as http;

import '../helpers/trade_payment_accounts_exceptions.dart';
import '../helpers/trade_payment_accounts_helpers.dart';
import '../models/trade_payment_accounts_dtos.dart';
import '../models/trade_payment_accounts_models.dart';
import 'trade_payment_accounts_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class TradePaymentAccountsService {
  TradePaymentAccountsService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw TradePaymentAccountsApiException(401, 'Missing JWT token');
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
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final wrapped = data[key];
        if (wrapped is Map<String, dynamic>) return wrapped;
      }
      return data;
    }
    return null;
  }

  Future<TradePaymentAccountsContext> getByOffer(
    String offerId, {
    TradePaymentAccountsQuery query = const TradePaymentAccountsQuery(),
  }) async {
    final res = await _client.get(
      TradePaymentAccountsHttp.uri(
        TradePaymentAccountsEndpoints.byOffer(offerId),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    TradePaymentAccountsHttp.ensureOk(res);
    final data = TradePaymentAccountsHttp.decodeJson(res);
    final map = _extractMap(data, keys: const ['data', 'item']);
    if (map != null) {
      return TradePaymentAccountsContext.fromJson(map);
    }

    throw TradePaymentAccountsApiException(
      res.statusCode,
      'Unexpected response for GET /trade-payment-accounts/offers/$offerId',
      body: res.body,
    );
  }

  void dispose() => _client.close();
}
