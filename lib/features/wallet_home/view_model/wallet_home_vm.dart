// lib/features/wallet_home/view_model/wallet_home_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/wallet_home/model/incoming_hint.dart';
import 'package:next_fi/features/wallet_home/model/wallet_home_state.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as stellar show PaymentOperationResponse, Asset;

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

// NEW: use the provider you built for deriving the account/keypair
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';

/// UI-neutral severity for toasts/snackbars
enum UiSeverity { info, success, warning, error }

/// ─────────────────── UI events (view-agnostic) ───────────────────
abstract class WalletHomeUiEvent {
  const WalletHomeUiEvent();
}

class BootBalancesLoading extends WalletHomeUiEvent {
  const BootBalancesLoading();
}

class BootBalancesReady extends WalletHomeUiEvent {
  final double xlm;
  final double usdc;
  const BootBalancesReady({required this.xlm, required this.usdc});
}

class IncomingHintAddedEvent extends WalletHomeUiEvent {
  final IncomingHint hint;
  const IncomingHintAddedEvent(this.hint);
}

class HintAcknowledgedEvent extends WalletHomeUiEvent {
  final String id;
  const HintAcknowledgedEvent(this.id);
}

class TransactionConfirmedEvent extends WalletHomeUiEvent {
  final String hash;
  final String asset;
  final double amount;
  const TransactionConfirmedEvent({
    required this.hash,
    required this.asset,
    required this.amount,
  });
}

/// Ask the View to show a short message
class ShowToastEvent extends WalletHomeUiEvent {
  final String message;
  final UiSeverity severity;
  const ShowToastEvent(this.message, this.severity);
}

/// Navigation / flow intents (View decides the actual UI)
class StartSendFlow extends WalletHomeUiEvent {
  final String address;
  final double xlm;
  final double usdc;
  const StartSendFlow({
    required this.address,
    required this.xlm,
    required this.usdc,
  });
}

class StartReceiveFlow extends WalletHomeUiEvent {
  final String address;
  final double xlm;
  final double usdc;
  final String? initialToken; // e.g. "XLM" | "USDC"
  const StartReceiveFlow({
    required this.address,
    required this.xlm,
    required this.usdc,
    this.initialToken,
  });
}

class NavigateToSwap extends WalletHomeUiEvent {
  const NavigateToSwap();
}

/// ───────────────────────── ViewModel ─────────────────────────
class WalletHomeVM extends ChangeNotifier {
  WalletHomeVM({
    required StellarWalletServices stellar,
    required SeedKeypairVM seedVM, // <— inject
  })  : _stellar = stellar,
        _seedVM = seedVM;

  final StellarWalletServices _stellar;
  final SeedKeypairVM _seedVM;

  WalletHomeState _state = const WalletHomeState();
  WalletHomeState get state => _state;

  void _set(WalletHomeState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  // ─────────────── UI events stream (for the View) ───────────────
  final StreamController<WalletHomeUiEvent> _ui = StreamController<WalletHomeUiEvent>.broadcast();
  Stream<WalletHomeUiEvent> get uiEvents => _ui.stream;
  void _emit(WalletHomeUiEvent e) {
    if (!_ui.isClosed) _ui.add(e);
  }

  // realtime + timers
  static const Duration _minBalancesGap = Duration(minutes: 1);
  bool _balancesInFlight = false;
  Timer? _balancesTimer;
  Timer? _debounceBalanceKick;

  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;
  StreamSubscription<Map>? _externalTxSub;
  final Set<String> _seen = <String>{};
  static const int _maxHints = 4;

  bool _disposed = false;
  bool _bootEventsArmed = true; // emit boot alerts once
  DateTime? _lastFetch;

  // ───────────────────── public API ─────────────────────

  Future<void> boot() async {
    if (_state.loadingWallet) return;
    _set(_state.copyWith(loadingWallet: true, loadingBalances: true));

    if (_bootEventsArmed) _emit(const BootBalancesLoading());

    try {
      // Load display name for header
      final name = (await SeedStorage.getActiveWalletMeta())?.name;

      // Ensure SeedKeypairVM is initialized and has (or derives) the public address
      await _seedVM.init(); // idempotent
      final address = _seedVM.accountId;

      if (address == null || address.isEmpty) {
        // No active wallet/seed
        _set(_state.copyWith(
          walletName: name,
          address: null,
          xlm: 0,
          usdc: 0,
          lastBalancesAt: DateTime.now(),
          loadingWallet: false,
          loadingBalances: false,
        ));
        if (_bootEventsArmed) {
          _emit(const BootBalancesReady(xlm: 0, usdc: 0));
          _bootEventsArmed = false;
        }
        return;
      }

      final changed = _state.address != address;
      _set(_state.copyWith(walletName: name, address: address));

      if (changed) _restartRealtime();
      await refresh(force: true);

      if (_bootEventsArmed) {
        _emit(BootBalancesReady(xlm: _state.xlm, usdc: _state.usdc));
        _bootEventsArmed = false;
      }
    } finally {
      _set(_state.copyWith(loadingWallet: false, loadingBalances: false));
      startRealtime();
    }
  }

  Future<bool> switchTo(String walletId) async {
    // Switch ACTIVE inside the seed VM (keeps meta/public in sync)
    final ok = await _seedVM.switchTo(walletId);
    if (!ok) return false;
    _bootEventsArmed = true;
    await boot();
    return true;
  }

  Future<void> refresh({bool force = false}) async {
    if (!_state.hasWallet) return;
    if (_balancesInFlight) return;
    if (!force && !_isStale(_lastFetch, _minBalancesGap)) return;

    _balancesInFlight = true;
    _set(_state.copyWith(loadingBalances: true));

    try {
      final addr = _state.address!;
      final results = await Future.wait<double>([
        _stellar.getXlmBalance(addr).catchError((_) => 0.0),
        _stellar.getUsdcBalance(addr).catchError((_) => 0.0),
      ], eagerError: false);

      final now = DateTime.now();
      _lastFetch = now;
      _set(_state.copyWith(
        xlm: results[0],
        usdc: results[1],
        lastBalancesAt: now,
      ));
    } finally {
      _balancesInFlight = false;
      _set(_state.copyWith(loadingBalances: false));
    }
  }

  void startRealtime() {
    if (!_state.hasWallet) return;
    stopRealtime();

    _balancesTimer = Timer.periodic(_minBalancesGap, (_) => refresh());

    _incomingSub = _stellar.paymentsStream(_state.address!).listen((op) {
      if (_disposed) return;
      if (op.transactionSuccessful != true) return;
      if (op.to != _state.address) return;

      final id = op.transactionHash ?? '';
      if (id.isEmpty || _seen.contains(id)) return;

      _seen.add(id);
      final hint = IncomingHint(
        id: id,
        from: op.from ?? '',
        to: op.to ?? '',
        assetCode: op.assetType == stellar.Asset.TYPE_NATIVE ? 'XLM' : (op.assetCode ?? 'ASSET'),
        amount: double.tryParse(op.amount) ?? 0.0,
        at: DateTime.now(),
      );

      final next = [hint, ..._state.hints];
      if (next.length > _maxHints) next.removeLast();

      _set(_state.copyWith(hints: next));
      _emit(IncomingHintAddedEvent(hint));

      _scheduleBalanceKick(const Duration(milliseconds: 400));
    }, onError: (_) {
      // silent; periodic refresh covers it
    });
  }

  /// Pipe an external "tx confirmed" stream (e.g., from TransactionsVM) into VM.
  /// The VM rebroadcasts it as a UI event for the View to update alerts.
  void attachConfirmedTxStream(Stream<Map> txStream) {
    _externalTxSub?.cancel();
    _externalTxSub = txStream.listen((tx) {
      if (_disposed) return;
      final hash = (tx['hash'] ?? '').toString();
      if (hash.isEmpty) return;
      final asset = (tx['asset'] ?? 'XLM').toString();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      _emit(TransactionConfirmedEvent(hash: hash, asset: asset, amount: amount));
    }, onError: (_) {});
  }

  void stopRealtime() {
    _balancesTimer?.cancel();
    _balancesTimer = null;
    _incomingSub?.cancel();
    _incomingSub = null;
    _externalTxSub?.cancel();
    _externalTxSub = null;
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = null;
  }

  void ackHint(String id) {
    final next = List.of(_state.hints)..removeWhere((h) => h.id == id);
    _seen.remove(id);
    _set(_state.copyWith(hints: next));
    _emit(HintAcknowledgedEvent(id));
  }

  Future<void> reloadActiveWalletName() async {
    final name = (await SeedStorage.getActiveWalletMeta())?.name;
    _set(_state.copyWith(walletName: name));
  }

  Future<bool> renameActiveWallet(String newName) async {
    final id = await SeedStorage.getActiveWalletId();
    if (id == null) return false;
    final ok = await SeedStorage.renameWallet(id, newName);
    if (ok) _set(_state.copyWith(walletName: newName.trim()));
    return ok;
  }

  // ─────────────── UI-intent API (called by View) ───────────────

  void onSwapPressed() {
    if (!_state.hasWallet) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }
    _emit(const NavigateToSwap());
  }

  void onSendPressed() {
    if (!_state.hasWallet || _state.address == null) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }
    _emit(StartSendFlow(address: _state.address!, xlm: _state.xlm, usdc: _state.usdc));
  }

  void onReceivePressed({String? initialToken}) {
    if (!_state.hasWallet || _state.address == null) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }
    _emit(StartReceiveFlow(
      address: _state.address!,
      xlm: _state.xlm,
      usdc: _state.usdc,
      initialToken: initialToken,
    ));
  }

  // app lifecycle hooks
  void onResumed() {
    startRealtime();
    // ignore: discarded_futures
    unawaited(refresh());
  }

  void onPausedOrInactive() {
    stopRealtime();
  }

  @override
  void dispose() {
    _disposed = true;
    stopRealtime();
    _ui.close();
    super.dispose();
  }

  // ───────────────────── helpers ─────────────────────
  bool _isStale(DateTime? last, Duration gap) =>
      last == null || DateTime.now().difference(last) >= gap;

  void _scheduleBalanceKick(Duration delay) {
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = Timer(delay, () => refresh(force: true));
  }

  void _restartRealtime() {
    stopRealtime();
  }
}
