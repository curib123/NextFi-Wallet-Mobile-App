import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/trade_payment_accounts_service.dart';
import 'models/trade_payment_accounts_dtos.dart';
import 'models/trade_payment_accounts_models.dart';

class TradePaymentAccountsCoreService {
  TradePaymentAccountsCoreService._();

  static final TradePaymentAccountsCoreService I =
      TradePaymentAccountsCoreService._();

  late final TradePaymentAccountsService _api = TradePaymentAccountsService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<TradePaymentAccountsContext> getOfferContext(
    String offerId, {
    bool? activeOnly,
  }) async => _api.getByOffer(
    offerId,
    query: TradePaymentAccountsQuery(activeOnly: activeOnly),
  );
}
