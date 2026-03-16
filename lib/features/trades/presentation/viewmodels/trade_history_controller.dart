import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/core/services/trades/models/trades_models.dart';
import 'package:next_fi/core/services/trades/trades_core_service.dart';
import 'package:next_fi/features/trades/presentation/viewmodels/trade_history_state.dart';

final tradeHistoryServiceProvider = Provider<TradesCoreService>(
  (Ref ref) => TradesCoreService.I,
);

final tradeHistoryControllerProvider =
    NotifierProvider.autoDispose<TradeHistoryController, TradeHistoryState>(
      TradeHistoryController.new,
    );

class TradeHistoryController extends Notifier<TradeHistoryState> {
  @override
  TradeHistoryState build() {
    Future<void>.microtask(loadTrades);
    return const TradeHistoryState();
  }

  Future<void> loadTrades({bool showLoader = true}) async {
    if (showLoader) {
      state = state.copyWith(loading: true, error: null);
    }

    try {
      final List<TradeModel> result = await ref
          .read(tradeHistoryServiceProvider)
          .list();
      if (!ref.mounted) return;
      state = state.copyWith(trades: result, loading: false, error: null);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  void setFilter(TradeHistoryFilterTab filter) {
    if (filter == state.activeFilter) return;
    state = state.copyWith(activeFilter: filter);
  }
}
