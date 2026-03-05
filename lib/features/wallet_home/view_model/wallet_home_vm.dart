// lib/features/wallet_home/view_model/wallet_home_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/wallet_home/model/incoming_hint.dart';
import 'package:next_fi/features/wallet_home/model/wallet_home_state.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart'
    as stellar
    show PaymentOperationResponse, Asset;

import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';

// ✅ add this import
import 'package:next_fi/services/fcm_notification/fcm_notification_core.dart';

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
  final String? initialToken;
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

/// Emitted when user is not authenticated and needs to login first.
class NavigateToLogin extends WalletHomeUiEvent {
  const NavigateToLogin();
}

/// Emitted when buy flow should start (user is authenticated).
class StartBuyFlow extends WalletHomeUiEvent {
  final String address;
  final double xlm;
  final double usdc;
  const StartBuyFlow({
    required this.address,
    required this.xlm,
    required this.usdc,
  });
}

/// Emitted when sell flow should start (user is authenticated).
class StartSellFlow extends WalletHomeUiEvent {
  final String address;
  final double xlm;
  final double usdc;
  const StartSellFlow({
    required this.address,
    required this.xlm,
    required this.usdc,
  });
}

/// ───────────────────────── ViewModel ─────────────────────────
class WalletHomeVM extends ChangeNotifier {
  WalletHomeVM({
    required StellarWalletServices stellar,
    required SeedKeypairVM seedVM,
    TokenStorage? tokenStorage,
  }) : _stellar = stellar,
       _seedVM = seedVM,
       _tokenStorage = tokenStorage ?? TokenStorage();

  final StellarWalletServices _stellar;
  final SeedKeypairVM _seedVM;
  final TokenStorage _tokenStorage;

  WalletHomeState _state = const WalletHomeState();
  WalletHomeState get state => _state;

  void _set(WalletHomeState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  // ─────────────── UI events stream (for the View) ───────────────
  final StreamController<WalletHomeUiEvent> _ui =
      StreamController<WalletHomeUiEvent>.broadcast();
  Stream<WalletHomeUiEvent> get uiEvents => _ui.stream;

  void _emit(WalletHomeUiEvent e) {
    if (!_ui.isClosed && !_disposed) _ui.add(e);
  }

  // Realtime + timers
  static const Duration _minBalancesGap = Duration(minutes: 1);
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  static const int _maxHints = 4;
  static const int _maxSeenHashes = 100;

  bool _balancesInFlight = false;
  Timer? _balancesTimer;
  Timer? _debounceBalanceKick;

  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;
  StreamSubscription<Map>? _externalTxSub;
  final Set<String> _seen = <String>{};

  bool _disposed = false;
  bool _bootEventsArmed = true;
  DateTime? _lastFetch;
  String? _lastBoundAddress;

  // ✅ throttle self-push (avoid spamming)
  DateTime? _lastSelfPushAt;
  static const Duration _minSelfPushGap = Duration(minutes: 3);

  // ───────────────────── Auth check helper ─────────────────────

  /// Returns true if user has valid OAuth tokens
  Future<bool> _isAuthenticated() async {
    try {
      final has = await _tokenStorage.hasTokens;
      return has == true;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  /// Ensures auth before protected flows
  Future<bool> _requireAuth() async {
    final authed = await _isAuthenticated();

    if (!authed) {
      debugPrint('User not authenticated → NavigateToLogin emitted');
      _emit(const NavigateToLogin());
      return false;
    }

    return true;
  }

  // ✅ Send push to self ONLY if logged in + throttled
  Future<void> _notifyMeIfAuthed({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (_disposed) return;

    // throttle
    final now = DateTime.now();
    if (_lastSelfPushAt != null &&
        now.difference(_lastSelfPushAt!) < _minSelfPushGap) {
      return;
    }

    final authed = await _isAuthenticated();
    if (!authed) return;

    try {
      await FcmNotificationCore().sendPushToMe(
        title: title,
        body: body,
        data: data ?? const {'route': '/wallet'},
      );
      _lastSelfPushAt = now;
      debugPrint('[FCM] sendPushToMe ok');
    } catch (e) {
      debugPrint('[FCM] sendPushToMe failed: $e');
    }
  }

  // ───────────────────── Buy / Sell ─────────────────────

  Future<void> onBuyPressed() async {
    if (!_state.hasWallet || _state.address == null) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }

    final authed = await _requireAuth();
    if (!authed) return;

    _emit(
      StartBuyFlow(
        address: _state.address!,
        xlm: _state.xlm,
        usdc: _state.usdc,
      ),
    );
  }

  Future<void> onSellPressed() async {
    if (!_state.hasWallet || _state.address == null) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }

    final authed = await _requireAuth();
    if (!authed) return;

    _emit(
      StartSellFlow(
        address: _state.address!,
        xlm: _state.xlm,
        usdc: _state.usdc,
      ),
    );
  }

  // ───────────────────── Binding helpers ─────────────────────

  void bindToAddress(String? addr) {
    final address = (addr ?? '').trim();

    if (address.isEmpty) {
      if (_state.address != null) {
        _set(
          _state.copyWith(
            address: null,
            xlm: 0,
            usdc: 0,
            xlmBaseReserve: 1.0,
            xlmTrustlineReserve: 0.0,
            xlmTotalReserve: 1.0,
            trustlineCount: 0,
          ),
        );
        _lastBoundAddress = null;
        _restartRealtime();
      }
      return;
    }

    if (_state.address == address && _lastBoundAddress == address) return;

    _lastBoundAddress = address;
    _set(_state.copyWith(address: address));
    _restartRealtime();
    _kickRefreshInBackground(force: true);
  }

  void bindToSeedVM() => bindToAddress(_seedVM.accountId);

  // ───────────────────── Public API ─────────────────────

  Future<void> boot() async {
    if (_state.loadingWallet) return;

    _set(_state.copyWith(loadingWallet: true, loadingBalances: true));

    if (_bootEventsArmed) _emit(const BootBalancesLoading());

    try {
      final name = (await SeedStorage.getActiveWalletMeta())?.name;

      await _seedVM.init();
      final address = _seedVM.accountId;

      if (address == null || address.isEmpty) {
        _set(
          _state.copyWith(
            walletName: name,
            address: null,
            xlm: 0,
            usdc: 0,
            lastBalancesAt: DateTime.now(),
            loadingWallet: false,
            loadingBalances: false,
          ),
        );

        if (_bootEventsArmed) {
          _emit(const BootBalancesReady(xlm: 0, usdc: 0));
          _bootEventsArmed = false;
        }
        return;
      }

      final changed = _state.address != address;
      _set(_state.copyWith(walletName: name, address: address));
      _lastBoundAddress = address;

      if (changed) _restartRealtime();

      await refresh(force: true);

      if (_bootEventsArmed) {
        _emit(BootBalancesReady(xlm: _state.xlm, usdc: _state.usdc));
        _bootEventsArmed = false;
      }
    } catch (e) {
      debugPrint('WalletHomeVM.boot error: $e');
      _emit(ShowToastEvent('Failed to load wallet: $e', UiSeverity.error));
    } finally {
      _set(_state.copyWith(loadingWallet: false, loadingBalances: false));
      startRealtime();
    }
  }

  Future<bool> switchTo(String walletId) async {
    try {
      final ok = await _seedVM.switchTo(walletId);
      if (!ok) return false;

      _bootEventsArmed = true;
      await boot();
      return true;
    } catch (e) {
      debugPrint('WalletHomeVM.switchTo error: $e');
      _emit(ShowToastEvent('Failed to switch wallet', UiSeverity.error));
      return false;
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!_state.hasWallet || _state.address == null) return;
    if (_balancesInFlight) return;
    if (!force && !_isStale(_lastFetch, _minBalancesGap)) return;

    _balancesInFlight = true;
    _set(_state.copyWith(loadingBalances: true));

    try {
      final addr = _state.address!;

      final results = await Future.wait<double>([
        _stellar.getXlmBalance(addr).catchError((e) {
          debugPrint('Error fetching XLM balance: $e');
          return 0.0;
        }),
        _stellar.getUsdcBalance(addr).catchError((e) {
          debugPrint('Error fetching USDC balance: $e');
          return 0.0;
        }),
      ], eagerError: false);

      final now = DateTime.now();
      _lastFetch = now;

      _set(
        _state.copyWith(xlm: results[0], usdc: results[1], lastBalancesAt: now),
      );

      await _fetchReserves(addr);
    } catch (e) {
      debugPrint('WalletHomeVM.refresh error: $e');
      if (force) {
        _emit(
          const ShowToastEvent(
            'Failed to refresh balances',
            UiSeverity.warning,
          ),
        );
      }
    } finally {
      _balancesInFlight = false;
      _set(_state.copyWith(loadingBalances: false));
    }
  }

  Future<void> _fetchReserves(String addr) async {
    if (!_state.hasWallet) return;

    _set(_state.copyWith(loadingReserves: true));

    try {
      final breakdown = await _stellar.getReserveBreakdown(addr);

      _set(
        _state.copyWith(
          xlmBaseReserve: breakdown['baseReserve'] ?? 1.0,
          xlmTrustlineReserve: breakdown['trustlineReserve'] ?? 0.0,
          xlmTotalReserve: breakdown['totalMinimumBalance'] ?? 1.0,
          trustlineCount: (breakdown['trustlineCount'] as num?)?.toInt() ?? 0,
          lastReservesAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching reserves: $e');
      _set(
        _state.copyWith(
          xlmBaseReserve: 1.0,
          xlmTrustlineReserve: 0.0,
          xlmTotalReserve: 1.0,
          trustlineCount: 0,
        ),
      );
    } finally {
      _set(_state.copyWith(loadingReserves: false));
    }
  }

  void startRealtime() {
    if (!_state.hasWallet || _state.address == null) return;

    stopRealtime();

    _balancesTimer = Timer.periodic(_minBalancesGap, (_) {
      if (!_disposed) _kickRefreshInBackground();
    });

    _incomingSub = _stellar
        .paymentsStream(_state.address!)
        .listen(
          (op) async {
            if (_disposed) return;

            if (op.transactionSuccessful != true) return;
            if (op.to != _state.address) return;

            final id = op.transactionHash ?? '';
            if (id.isEmpty || _seen.contains(id)) return;

            _seen.add(id);
            _pruneSeenSet();

            final assetCode = op.assetType == stellar.Asset.TYPE_NATIVE
                ? 'XLM'
                : (op.assetCode ?? 'ASSET');

            final amount = double.tryParse(op.amount ?? '0') ?? 0.0;

            final hint = IncomingHint(
              id: id,
              from: op.from ?? '',
              to: op.to ?? '',
              assetCode: assetCode,
              amount: amount,
              at: DateTime.now(),
            );

            final next = [hint, ..._state.hints];
            if (next.length > _maxHints) {
              next.removeRange(_maxHints, next.length);
            }

            _set(_state.copyWith(hints: next));
            _emit(IncomingHintAddedEvent(hint));

            // ✅ OPTIONAL: send a push to yourself (only if logged in + throttled)
            await _notifyMeIfAuthed(
              title: 'Incoming $assetCode',
              body: '+$amount $assetCode received',
              data: const {'route': '/wallet'},
            );

            _scheduleBalanceKick(_debounceDelay);
          },
          onError: (e) {
            debugPrint('Payment stream error: $e');
          },
          cancelOnError: false,
        );
  }

  void attachConfirmedTxStream(Stream<Map> txStream) {
    _externalTxSub?.cancel();
    _externalTxSub = txStream.listen(
      (tx) async {
        if (_disposed) return;

        final hash = (tx['hash'] ?? '').toString().trim();
        if (hash.isEmpty) return;

        final asset = (tx['asset'] ?? 'XLM').toString();
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        _emit(
          TransactionConfirmedEvent(hash: hash, asset: asset, amount: amount),
        );

        // ✅ OPTIONAL: self-push on confirmations too (logged-in + throttled)
        await _notifyMeIfAuthed(
          title: 'Transaction confirmed',
          body: '$amount $asset confirmed',
          data: const {'route': '/wallet'},
        );
      },
      onError: (e) {
        debugPrint('External tx stream error: $e');
      },
      cancelOnError: false,
    );
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
    if (id.isEmpty) return;

    final next = List.of(_state.hints)..removeWhere((h) => h.id == id);
    _seen.remove(id);
    _set(_state.copyWith(hints: next));
    _emit(HintAcknowledgedEvent(id));
  }

  Future<void> reloadActiveWalletName() async {
    try {
      final name = (await SeedStorage.getActiveWalletMeta())?.name;
      _set(_state.copyWith(walletName: name));
    } catch (e) {
      debugPrint('Error reloading wallet name: $e');
    }
  }

  Future<bool> renameActiveWallet(String newName) async {
    try {
      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) return false;

      final id = await SeedStorage.getActiveWalletId();
      if (id == null) return false;

      final ok = await SeedStorage.renameWallet(id, trimmedName);
      if (ok) {
        _set(_state.copyWith(walletName: trimmedName));
      }
      return ok;
    } catch (e) {
      debugPrint('Error renaming wallet: $e');
      return false;
    }
  }

  void setPriceWindow(PriceWindow window) {
    if (_state.selectedWindow == window) return;
    _set(_state.copyWith(selectedWindow: window));
  }

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

    _emit(
      StartSendFlow(
        address: _state.address!,
        xlm: _state.xlm,
        usdc: _state.usdc,
      ),
    );
  }

  void onReceivePressed({String? initialToken}) {
    if (!_state.hasWallet || _state.address == null) {
      _emit(const ShowToastEvent('Wallet not loaded yet', UiSeverity.warning));
      return;
    }

    _emit(
      StartReceiveFlow(
        address: _state.address!,
        xlm: _state.xlm,
        usdc: _state.usdc,
        initialToken: initialToken,
      ),
    );
  }

  void onResumed() {
    if (!_disposed) {
      startRealtime();
      _kickRefreshInBackground();
    }
  }

  void onPausedOrInactive() {
    stopRealtime();
  }

  @override
  void dispose() {
    _disposed = true;
    stopRealtime();

    if (!_ui.isClosed) {
      _ui.close();
    }

    _seen.clear();

    super.dispose();
  }

  // ───────────────────── Private helpers ─────────────────────

  bool _isStale(DateTime? last, Duration gap) {
    if (last == null) return true;
    return DateTime.now().difference(last) >= gap;
  }

  void _scheduleBalanceKick(Duration delay) {
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = Timer(delay, () {
      if (!_disposed) _kickRefreshInBackground(force: true);
    });
  }

  void _restartRealtime() {
    stopRealtime();
    if (!_disposed && _state.hasWallet) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_disposed) startRealtime();
      });
    }
  }

  void _pruneSeenSet() {
    if (_seen.length > _maxSeenHashes) {
      final toRemove = _seen.length - _maxSeenHashes;
      final iterator = _seen.iterator;
      for (var i = 0; i < toRemove && iterator.moveNext(); i++) {
        _seen.remove(iterator.current);
      }
    }
  }

  void _kickRefreshInBackground({bool force = false}) {
    refresh(force: force).catchError((e) {
      debugPrint('Background refresh error: $e');
    });
  }
}
