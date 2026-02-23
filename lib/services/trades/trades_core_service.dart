import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:next_fi/services/trades/api/trades_service.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';

class TradesCoreService {
  TradesCoreService._();

  static final TradesCoreService I = TradesCoreService._();

  late final TradesService _api = TradesService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      return await TokenStorage().accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<TradeModel> create(CreateTradeRequest req) => _api.create(req);

  Future<TradesPagedResponse> listPaged({
    TradesListQuery query = const TradesListQuery(),
  }) => _api.listPaged(query: query);

  Future<List<TradeModel>> list({
    TradesListQuery query = const TradesListQuery(),
  }) async {
    final page = await _api.listPaged(query: query);
    return page.items;
  }

  Future<TradeModel> getOne(String id) => _api.getOne(id);

  Future<TradeModel> markFiatSent(String id) => _api.markFiatSent(id);

  Future<TradeModel> confirmFiat(String id, {String? fiatRefNo}) =>
      _api.confirmFiat(id, fiatRefNo: fiatRefNo);

  Future<TradeModel> cancelTrade(String id, {String? reason}) =>
      _api.cancelTrade(id, reason: reason);

  void dispose() => _api.dispose();
}
