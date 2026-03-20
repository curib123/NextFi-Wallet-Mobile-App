import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/core/services/trades/models/trades_models.dart';
import 'package:next_fi/core/services/trades/trades_core_service.dart';

class TradeInboxSummary {
  const TradeInboxSummary({
    required this.trades,
    required this.activeTradeCount,
    required this.merchantActionCount,
  });

  final List<TradeModel> trades;
  final int activeTradeCount;
  final int merchantActionCount;
}

final tradeInboxSummaryProvider = FutureProvider.autoDispose<TradeInboxSummary>(
  (Ref ref) async {
    final trades = await TradesCoreService.I.list();
    return TradeInboxSummary(
      trades: trades,
      activeTradeCount: trades.where((trade) => trade.status.isActive).length,
      merchantActionCount: trades.where(_requiresMerchantAction).length,
    );
  },
);

bool _requiresMerchantAction(TradeModel trade) {
  switch (trade.status) {
    case TradeStatus.starting:
      return true;
    case TradeStatus.created:
      return trade.offerType == TradeOfferType.sell;
    case TradeStatus.fiatSent:
      return true;
    case TradeStatus.fiatConfirmed:
      return trade.offerType == TradeOfferType.buy;
    case TradeStatus.cryptoLocked:
    case TradeStatus.completed:
    case TradeStatus.cancelled:
    case TradeStatus.disputed:
    case TradeStatus.expired:
    case TradeStatus.unknown:
      return false;
  }
}
