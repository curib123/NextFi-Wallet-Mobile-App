import 'package:next_fi/core/services/trades/models/trades_models.dart';

const Object _sentinel = Object();

class MerchantTradesState {
  const MerchantTradesState({
    this.loading = true,
    this.error,
    this.trades = const <TradeModel>[],
    this.activeFilter,
  });

  final bool loading;
  final String? error;
  final List<TradeModel> trades;
  final bool? activeFilter;

  List<TradeModel> get filteredTrades {
    if (activeFilter == null) return trades;
    if (activeFilter == true) {
      return trades.where((TradeModel trade) => trade.status.isActive).toList();
    }
    return trades.where((TradeModel trade) => trade.status.isTerminal).toList();
  }

  MerchantTradesState copyWith({
    bool? loading,
    Object? error = _sentinel,
    List<TradeModel>? trades,
    Object? activeFilter = _sentinel,
  }) {
    return MerchantTradesState(
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      trades: trades ?? this.trades,
      activeFilter: identical(activeFilter, _sentinel)
          ? this.activeFilter
          : activeFilter as bool?,
    );
  }
}
