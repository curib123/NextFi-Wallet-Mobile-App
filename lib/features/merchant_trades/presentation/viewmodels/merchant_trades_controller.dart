import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/core/services/trades/models/trades_models.dart';
import 'package:next_fi/core/services/trades/trades_core_service.dart';
import 'package:next_fi/features/merchant_trades/presentation/viewmodels/merchant_trades_state.dart';

final merchantTradesServiceProvider = Provider<TradesCoreService>(
  (Ref ref) => TradesCoreService.I,
);

final merchantTradesControllerProvider =
    NotifierProvider.autoDispose<MerchantTradesController, MerchantTradesState>(
      MerchantTradesController.new,
    );

class MerchantTradesController extends Notifier<MerchantTradesState> {
  @override
  MerchantTradesState build() {
    Future<void>.microtask(load);
    return const MerchantTradesState();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: null);
    }

    try {
      final List<TradeModel> trades = await ref
          .read(merchantTradesServiceProvider)
          .list();
      if (!ref.mounted) return;
      state = state.copyWith(trades: trades, loading: false, error: null);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  void setFilter(bool? value) {
    state = state.copyWith(activeFilter: value);
  }
}
