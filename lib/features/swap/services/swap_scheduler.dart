// lib/features/swap/data/swap_scheduler.dart
import 'dart:async';
import 'package:uuid/uuid.dart';

import 'package:next_fi/features/swap/data/swap_order_store.dart';
import 'package:next_fi/features/swap/model/swap_order.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

class SwapScheduler {
  final StellarWalletServices svc;
  final SwapOrderStore store;
  final SeedKeypairVM keys;

  StreamSubscription? _priceSub;
  Timer? _tick;

  final _ordersCtrl = StreamController<List<SwapOrder>>.broadcast();
  List<SwapOrder> _orders = [];

  bool _started = false;
  bool _executing = false; // prevent overlapping executions

  Stream<List<SwapOrder>> get ordersStream => _ordersCtrl.stream;

  SwapScheduler({
    required this.svc,
    required this.store,
    required this.keys,
  });

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _orders = await store.load();
    _emit();

    // price stream: emits objects with .usdcPerXlm (or num)
    _priceSub = svc.xlmUsdcPriceStream().listen(_onPrice, onError: (_) {});
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _onTimer());
  }

  Future<void> stop() async {
    await _priceSub?.cancel();
    _priceSub = null;
    _tick?.cancel();
    _tick = null;
    _started = false;
  }

  void dispose() {
    // Fire-and-forget is fine here; call stop() yourself if you need to await.
    stop();
    _ordersCtrl.close();
  }

  // API ---------------------------------------------------------------------

  Future<SwapOrder> placeLimit({
    required SwapOrderSide side,
    required double amountFrom,
    required double slippagePct, // fractional (e.g., 0.01 = 1%)
    required double limitPriceUsdcPerXlm,
    DateTime? notBefore,
  }) async {
    final o = SwapOrder(
      id: const Uuid().v4(),
      side: side,
      amountFrom: amountFrom,
      slippagePct: slippagePct,
      limitPriceUsdcPerXlm: limitPriceUsdcPerXlm,
      scheduleAt: notBefore,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, o);
    await store.upsert(o);
    _emit();
    return o;
  }

  Future<SwapOrder> placeScheduleAt({
    required SwapOrderSide side,
    required double amountFrom,
    required double slippagePct, // fractional
    required DateTime scheduleAt,
  }) async {
    final o = SwapOrder(
      id: const Uuid().v4(),
      side: side,
      amountFrom: amountFrom,
      slippagePct: slippagePct,
      scheduleAt: scheduleAt,
      createdAt: DateTime.now(),
    );
    _orders.insert(0, o);
    await store.upsert(o);
    _emit();
    return o;
  }

  Future<void> cancel(String id) async {
    final i = _orders.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _orders[i] = _orders[i].copyWith(active: false);
      await store.upsert(_orders[i]);
      _emit();
    }
  }

  // Internal ---------------------------------------------------------------

  void _emit() => _ordersCtrl.add(List.unmodifiable(_orders));

  void _onTimer() => _tryExecute(triggerPrice: null);

  void _onPrice(dynamic p) {
    // Accept either a model with .usdcPerXlm or a plain num.
    double? price;
    if (p is num) {
      price = p.toDouble();
    } else {
      try {
        final v = (p.usdcPerXlm as num?)?.toDouble();
        price = v;
      } catch (_) {}
    }
    if (price != null) _tryExecute(triggerPrice: price);
  }

  Future<void> _tryExecute({double? triggerPrice}) async {
    if (_executing) return; // skip if a run is already in progress
    _executing = true;

    try {
      final now = DateTime.now();
      final active = _orders.where((o) => o.active).toList();
      if (active.isEmpty) return;

      // Ensure we have an account and can derive a keypair
      if ((keys.accountId ?? '').isEmpty) {
        // Mark all due orders with a helpful error message and skip this tick
        for (final o in active) {
          if (_isDue(o, now, triggerPrice)) {
            await _markError(o, 'No active wallet/account available.');
          }
        }
        return;
      }

      // Derive keypair once per tick (avoid multiple secure ops)
      final kp = await keys.deriveKeyPair();

      for (final o in active) {
        if (!_isDue(o, now, triggerPrice)) continue;

        try {
          final est = (o.side == SwapOrderSide.xlmToUsdc)
              ? await svc.quoteXlmToUsdc(o.amountFrom)
              : await svc.quoteUsdcToXlm(o.amountFrom);
          if (est == null || est <= 0) {
            throw Exception('Quote unavailable');
          }

          final minOut = est * (1.0 - o.slippagePct);

          final txid = (o.side == SwapOrderSide.xlmToUsdc)
              ? await svc.swapXlmToUsdc(
            keyPair: kp,
            sendAmountXlm: o.amountFrom,
            minUsdcOut: minOut,
          )
              : await svc.swapUsdcToXlm(
            keyPair: kp,
            sendAmountUsdc: o.amountFrom,
            minXlmOut: minOut,
          );

          final done = o.copyWith(
            active: false,
            txId: txid,
            executedAt: DateTime.now(),
            lastError: null,
          );
          await _upsertLocal(done);
        } catch (e) {
          await _markError(o, e.toString());
        }
      }
    } finally {
      _executing = false;
    }
  }

  bool _isDue(SwapOrder o, DateTime now, double? triggerPrice) {
    // schedule gate
    if (o.scheduleAt != null && now.isBefore(o.scheduleAt!)) return false;

    // limit gate
    if (o.limitPriceUsdcPerXlm != null) {
      if (triggerPrice == null) return false;
      final want = o.limitPriceUsdcPerXlm!;
      final hit = (o.side == SwapOrderSide.xlmToUsdc)
          ? triggerPrice >= want // sell XLM when price high
          : triggerPrice <= want; // buy XLM when price cheap
      if (!hit) return false;
    } else if (o.scheduleAt == null) {
      // neither limit nor schedule -> invalid order shape; skip
      return false;
    }

    return true;
  }

  Future<void> _markError(SwapOrder o, String err) async {
    final failed = o.copyWith(lastError: err);
    await _upsertLocal(failed);
  }

  Future<void> _upsertLocal(SwapOrder updated) async {
    final idx = _orders.indexWhere((x) => x.id == updated.id);
    if (idx >= 0) {
      _orders[idx] = updated;
    } else {
      _orders.insert(0, updated);
    }
    await store.upsert(updated);
    _emit();
  }
}
