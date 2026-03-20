import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/features/wallet_home/data/services/wallet_home_flow_service.dart';
import 'package:next_fi/features/wallet_home/data/models/incoming_hint.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart'
    as stellar
    show PaymentOperationResponse, Asset, Balance;

import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';

enum UiSeverity { info, success, warning, error }

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

class ShowToastEvent extends WalletHomeUiEvent {
  final String message;
  final UiSeverity severity;
  const ShowToastEvent(this.message, this.severity);
}

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

class NavigateToLogin extends WalletHomeUiEvent {
  const NavigateToLogin();
}

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

class WalletHomeVM extends ChangeNotifier {
  WalletHomeVM({
    required StellarWalletServices stellar,
    required SeedKeypairVM seedVM,
    required AssetVM assetVM,
    TokenStorage? tokenStorage,
    WalletHomeFlowService? flowService,
  }) : _stellar = stellar,
       _seedVM = seedVM,
       _assetVM = assetVM,
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _flowService = flowService ?? WalletHomeFlowService();

  final StellarWalletServices _stellar;
  final SeedKeypairVM _seedVM;
  final AssetVM _assetVM;
  final TokenStorage _tokenStorage;
  final WalletHomeFlowService _flowService;
  static const FlutterSecureStorage _store = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const String _balancesCacheKeyPrefix =
      'nextfi.wallet_home.balance_snapshot.v1.';

  WalletHomeState _state = const WalletHomeState();
  WalletHomeState get state => _state;
  bool _notifyScheduled = false;

  void _set(WalletHomeState s) {
    _state = s;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      notifyListeners();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  final StreamController<WalletHomeUiEvent> _ui =
      StreamController<WalletHomeUiEvent>.broadcast();
  Stream<WalletHomeUiEvent> get uiEvents => _ui.stream;

  void _emit(WalletHomeUiEvent e) {
    if (!_ui.isClosed && !_disposed) _ui.add(e);
  }

  static const Duration _minBalancesGap = Duration(minutes: 1);
  static const Duration _inactiveRefreshThreshold = Duration(minutes: 5);
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
  DateTime? _inactiveAt;
  String? _lastBoundAddress;
  String? _lastAutoSavedAddress;

  Future<bool> _isAuthenticated() async {
    try {
      final has = await _tokenStorage.hasTokens;
      return has == true;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  Future<bool> _requireAuth() async {
    final authed = await _isAuthenticated();

    if (!authed) {
      debugPrint('User not authenticated -> NavigateToLogin emitted');
      _emit(const NavigateToLogin());
      return false;
    }

    return true;
  }

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

  Future<void> ensureActiveWalletSavedIfMissing() async {
    final address = (_state.address ?? '').trim();
    if (address.isEmpty || _lastAutoSavedAddress == address) return;

    final label = (_state.walletName ?? '').trim();
    final saved = await _flowService.ensureWalletSavedIfMissing(
      address: address,
      label: label.isEmpty ? null : label,
    );
    if (saved) {
      _lastAutoSavedAddress = address;
    }
  }

  Future<bool> hasTradeAccess() => _flowService.hasTradeAccess();

  void bindToAddress(String? addr) {
    final address = (addr ?? '').trim();

    if (address.isEmpty) {
      if (_state.address != null) {
        _set(
          _state.copyWith(
            address: null,
            balancesByAssetId: const {},
            hasHydratedBalances: false,
            xlmBaseReserve: 1.0,
            xlmTrustlineReserve: 0.0,
            xlmTotalReserve: 1.0,
            trustlineCount: 0,
            lastBalancesAt: null,
            lastReservesAt: null,
          ),
        );
        _lastBoundAddress = null;
        _restartRealtime();
      }
      return;
    }

    if (_state.address == address && _lastBoundAddress == address) return;

    final changed = _state.address != address;
    _lastBoundAddress = address;
    _set(
      _state.copyWith(
        address: address,
        balancesByAssetId: changed ? const {} : _state.balancesByAssetId,
        hasHydratedBalances: changed ? false : _state.hasHydratedBalances,
        xlmBaseReserve: changed ? 1.0 : _state.xlmBaseReserve,
        xlmTrustlineReserve: changed ? 0.0 : _state.xlmTrustlineReserve,
        xlmTotalReserve: changed ? 1.0 : _state.xlmTotalReserve,
        trustlineCount: changed ? 0 : _state.trustlineCount,
        lastBalancesAt: changed ? null : _state.lastBalancesAt,
        lastReservesAt: changed ? null : _state.lastReservesAt,
      ),
    );
    _restartRealtime();
    _kickRefreshInBackground(force: true);
  }

  void bindToSeedVM() => bindToAddress(_seedVM.accountId);

  Future<void> boot() async {
    if (_state.loadingWallet) return;

    final shouldShowBalanceLoader = !_state.hasHydratedBalances;
    _set(
      _state.copyWith(
        loadingWallet: true,
        loadingBalances: shouldShowBalanceLoader,
      ),
    );

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
            balancesByAssetId: const {},
            hasHydratedBalances: false,
            lastBalancesAt: null,
            lastReservesAt: null,
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
      _set(
        _state.copyWith(
          walletName: name,
          address: address,
          balancesByAssetId: changed ? const {} : _state.balancesByAssetId,
          hasHydratedBalances: changed ? false : _state.hasHydratedBalances,
          xlmBaseReserve: changed ? 1.0 : _state.xlmBaseReserve,
          xlmTrustlineReserve: changed ? 0.0 : _state.xlmTrustlineReserve,
          xlmTotalReserve: changed ? 1.0 : _state.xlmTotalReserve,
          trustlineCount: changed ? 0 : _state.trustlineCount,
          lastBalancesAt: changed ? null : _state.lastBalancesAt,
          lastReservesAt: changed ? null : _state.lastReservesAt,
        ),
      );
      _lastBoundAddress = address;

      if (changed) _restartRealtime();

      await _hydrateCachedSnapshot(address);
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
    final shouldShowLoader = !_state.hasHydratedBalances;
    if (shouldShowLoader) {
      _set(_state.copyWith(loadingBalances: true));
    }

    try {
      final addr = _state.address!;
      final balancesByAssetId = await _fetchAssetBalances(addr);

      final now = DateTime.now();
      _lastFetch = now;

      _set(
        _state.copyWith(
          balancesByAssetId: balancesByAssetId,
          hasHydratedBalances: true,
          lastBalancesAt: now,
        ),
      );
      unawaited(_persistCachedSnapshot());

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
      if (_state.loadingBalances) {
        _set(_state.copyWith(loadingBalances: false));
      }
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
      unawaited(_persistCachedSnapshot());
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

            final id = op.transactionHash;
            if (id.isEmpty || _seen.contains(id)) return;

            _seen.add(id);
            _pruneSeenSet();

            final assetCode = op.assetType == stellar.Asset.TYPE_NATIVE
                ? 'XLM'
                : (op.assetCode ?? 'ASSET');

            final amount = double.tryParse(op.amount) ?? 0.0;

            final hint = IncomingHint(
              id: id,
              from: op.from,
              to: op.to,
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
        _kickRefreshInBackground(force: true);
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
    if (_disposed) return;

    final inactiveFor = _inactiveAt == null
        ? null
        : DateTime.now().difference(_inactiveAt!);
    _inactiveAt = null;

    startRealtime();

    if (inactiveFor == null || inactiveFor >= _inactiveRefreshThreshold) {
      _kickRefreshInBackground(force: inactiveFor != null);
    }
  }

  void onPausedOrInactive() {
    _inactiveAt ??= DateTime.now();
    stopRealtime();
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyScheduled = false;
    stopRealtime();

    if (!_ui.isClosed) {
      _ui.close();
    }

    _seen.clear();

    super.dispose();
  }

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

  Future<Map<String, double>> _fetchAssetBalances(String address) async {
    final assets = _stellarAssets;
    if (assets.isEmpty) {
      return const {};
    }

    final rawBalances = await _stellar.getAllBalances(address).catchError((e) {
      debugPrint('Error fetching account balances: $e');
      return <stellar.Balance>[];
    });
    final spendableXlm = await _stellar.getXlmBalance(address).catchError((e) {
      debugPrint('Error fetching spendable XLM balance: $e');
      return 0.0;
    });

    final next = <String, double>{};
    for (final asset in assets) {
      if (asset.isNative) {
        next[asset.id] = spendableXlm;
        continue;
      }

      stellar.Balance? match;
      for (final balance in rawBalances.whereType<stellar.Balance>()) {
        if (balance.assetCode == asset.assetCode &&
            balance.assetIssuer == asset.issuer) {
          match = balance;
          break;
        }
      }

      if (match == null) {
        next[asset.id] = 0.0;
        continue;
      }

      final balance = double.tryParse(match.balance) ?? 0.0;
      final liabilities =
          double.tryParse(match.sellingLiabilities ?? '0') ?? 0.0;
      final spendable = balance - liabilities;
      next[asset.id] = spendable > 0 ? spendable : 0.0;
    }
    return Map<String, double>.unmodifiable(next);
  }

  List<AssetModel> get _stellarAssets => _assetVM.assets
      .where(
        (asset) =>
            asset.enabled &&
            asset.chain.toLowerCase() == 'stellar' &&
            (asset.isNative ||
                ((asset.assetCode ?? '').isNotEmpty &&
                    (asset.issuer ?? '').isNotEmpty)),
      )
      .toList(growable: false);

  void _kickRefreshInBackground({bool force = false}) {
    refresh(force: force).catchError((e) {
      debugPrint('Background refresh error: $e');
    });
  }

  Future<void> _hydrateCachedSnapshot(String address) async {
    try {
      final raw = await _store.read(key: _cacheKeyForAddress(address));
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final balanceMap = _normalizeBalancesMap(decoded['balancesByAssetId']);
      final lastBalancesAt = _parseDateTime(decoded['lastBalancesAt']);
      final lastReservesAt = _parseDateTime(decoded['lastReservesAt']);
      final hasSnapshot =
          balanceMap.isNotEmpty ||
          lastBalancesAt != null ||
          lastReservesAt != null;
      if (!hasSnapshot) return;

      _set(
        _state.copyWith(
          balancesByAssetId: balanceMap,
          hasHydratedBalances: true,
          lastBalancesAt: lastBalancesAt,
          xlmBaseReserve: _toDouble(decoded['xlmBaseReserve']) ?? 1.0,
          xlmTrustlineReserve: _toDouble(decoded['xlmTrustlineReserve']) ?? 0.0,
          xlmTotalReserve: _toDouble(decoded['xlmTotalReserve']) ?? 1.0,
          trustlineCount: _toInt(decoded['trustlineCount']) ?? 0,
          lastReservesAt: lastReservesAt,
        ),
      );
    } catch (e) {
      debugPrint('WalletHomeVM cache hydrate error: $e');
    }
  }

  Future<void> _persistCachedSnapshot() async {
    final address = (_state.address ?? '').trim();
    if (address.isEmpty) return;

    try {
      await _store.write(
        key: _cacheKeyForAddress(address),
        value: jsonEncode({
          'balancesByAssetId': _state.balancesByAssetId,
          'xlmBaseReserve': _state.xlmBaseReserve,
          'xlmTrustlineReserve': _state.xlmTrustlineReserve,
          'xlmTotalReserve': _state.xlmTotalReserve,
          'trustlineCount': _state.trustlineCount,
          'lastBalancesAt': _state.lastBalancesAt?.toUtc().toIso8601String(),
          'lastReservesAt': _state.lastReservesAt?.toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('WalletHomeVM cache persist error: $e');
    }
  }

  String _cacheKeyForAddress(String address) =>
      '$_balancesCacheKeyPrefix${address.trim()}';

  DateTime? _parseDateTime(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, double> _normalizeBalancesMap(dynamic value) {
    if (value is Map<String, double>) {
      return Map<String, double>.unmodifiable(value);
    }

    if (value is Map) {
      final next = <String, double>{};
      for (final entry in value.entries) {
        final key = entry.key?.toString().trim();
        if (key == null || key.isEmpty) continue;
        next[key] = _toDouble(entry.value) ?? 0.0;
      }
      return Map<String, double>.unmodifiable(next);
    }

    return const <String, double>{};
  }
}
