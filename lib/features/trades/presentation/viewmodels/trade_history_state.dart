import 'package:next_fi/core/services/trades/models/trades_models.dart';

enum TradeHistoryFilterTab { all, buy, sell }

const Object _sentinel = Object();

class TradeHistoryState {
  const TradeHistoryState({
    this.loading = true,
    this.error,
    this.trades = const <TradeModel>[],
    this.activeFilter = TradeHistoryFilterTab.all,
  });

  final bool loading;
  final String? error;
  final List<TradeModel> trades;
  final TradeHistoryFilterTab activeFilter;

  List<TradeModel> get filteredTrades {
    return switch (activeFilter) {
      TradeHistoryFilterTab.all => trades,
      TradeHistoryFilterTab.buy =>
        trades
            .where((TradeModel trade) => trade.offerType == TradeOfferType.buy)
            .toList(),
      TradeHistoryFilterTab.sell =>
        trades
            .where((TradeModel trade) => trade.offerType == TradeOfferType.sell)
            .toList(),
    };
  }

  TradeHistoryState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<TradeModel>? trades,
    TradeHistoryFilterTab? activeFilter,
  }) {
    return TradeHistoryState(
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      trades: trades ?? this.trades,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}
