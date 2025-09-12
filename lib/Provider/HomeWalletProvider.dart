// lib/Provider/WalletHomeProvider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart'
as stellar show PaymentOperationResponse, Asset;

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class IncomingHint {
  final String id;
  final String from;
  final String to;
  final String assetCode;
  final double amount;
  final DateTime at;
  const IncomingHint({
    required this.id,
    required this.from,
    required this.to,
    required this.assetCode,
    required this.amount,
    required this.at,
  });
}

class WalletHomeProvider extends ChangeNotifier {
  WalletHomeProvider({StellarWalletService? stellar})
      : _stellar = stellar ?? StellarWalletService();

  final StellarWalletService _stellar;

  String? address;
  String? walletName; // expose active wallet name
  bool get hasWallet => address != null && address!.isNotEmpty;

  // Balances
  double xlm = 0, usdc = 0;
  bool loadingWallet = false;
  bool loadingBalances = false;
  DateTime? lastBalancesAt;

  // Incoming payments strip (lightweight)
  final List<IncomingHint> hints = <IncomingHint>[];
  final Set<String> _seen = <String>{};
  static const int _maxHints = 4;

  // Scheduling / realtime
  static const Duration _minBalancesGap = Duration(minutes: 1);
  bool _balancesInFlight = false;
  DateTime? _lastFetch;
  Timer? _balancesTimer;
  Timer? _debounceBalanceKick;

  // Now typed to the PaymentOperationResponse from the SDK (via the service stream)
  StreamSubscription<stellar.PaymentOperationResponse>? _incomingSub;

  bool _disposed = false;
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  String get walletDisplayName => walletName ?? 'Primary Wallet';

  // ---------- Public API ----------
  Future<void> boot() async {
    if (loadingWallet) return;
    loadingWallet = true;
    loadingBalances = true;
    _safeNotify();

    try {
      walletName = (await SeedStorage.getActiveWalletMeta())?.name;

      final mnemonic = await SeedStorage.getActiveSeed();
      if (mnemonic == null || mnemonic.trim().isEmpty) {
        address = null;
        xlm = 0;
        usdc = 0;
        lastBalancesAt = DateTime.now();
        return;
      }
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);
      final changed = address != kp.accountId;

      address = kp.accountId;
      if (changed) _restartRealtime();

      await refresh(force: true);
    } finally {
      loadingWallet = false;
      loadingBalances = false;
      _safeNotify();
      startRealtime();
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!hasWallet) return;
    if (_balancesInFlight) return;
    if (!force && !_isStale(_lastFetch, _minBalancesGap)) return;

    _balancesInFlight = true;
    loadingBalances = true;
    _safeNotify();

    try {
      final results = await Future.wait<double>([
        _stellar.getXlmBalance(address!).catchError((_) => 0.0),
        _stellar.getUsdcBalance(address!).catchError((_) => 0.0),
      ], eagerError: false);

      xlm = results[0];
      usdc = results[1];
      lastBalancesAt = DateTime.now();
      _lastFetch = lastBalancesAt;
    } finally {
      _balancesInFlight = false;
      loadingBalances = false;
      _safeNotify();
    }
  }

  void startRealtime() {
    if (!hasWallet) return;
    stopRealtime();

    // periodic refresh (respects _minBalancesGap via refresh())
    _balancesTimer = Timer.periodic(_minBalancesGap, (_) => refresh());

    // Subscribe to payments via the service (SSE under the hood)
    _incomingSub = _stellar
        .paymentsStream(address!)
        .listen((op) {
      if (_disposed) return;
      if (op.transactionSuccessful != true) return;
      if (op.to != address) return;

      final id = op.transactionHash ?? '';
      if (id.isEmpty || _seen.contains(id)) return;

      _seen.add(id);
      hints.insert(
        0,
        IncomingHint(
          id: id,
          from: op.from ?? '',
          to: op.to ?? '',
          assetCode: op.assetType == stellar.Asset.TYPE_NATIVE
              ? 'XLM'
              : (op.assetCode ?? 'ASSET'),
          amount: double.tryParse(op.amount) ?? 0.0,
          at: DateTime.now(),
        ),
      );
      if (hints.length > _maxHints) {
        final removed = hints.removeLast();
        _seen.remove(removed.id);
      }

      _scheduleBalanceKick(const Duration(milliseconds: 400));
      _safeNotify();
    }, onError: (_) {
      // No-op; manual refresh & timer cover transient issues
    });
  }

  void stopRealtime() {
    _balancesTimer?.cancel();
    _balancesTimer = null;
    _incomingSub?.cancel();
    _incomingSub = null;
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = null;
  }

  void _restartRealtime() {
    stopRealtime();
  }

  void ackHint(String id) {
    hints.removeWhere((h) => h.id == id);
    _seen.remove(id);
    _safeNotify();
  }

  /// Refresh only the active wallet metadata (e.g., after rename elsewhere)
  Future<void> reloadActiveWalletName() async {
    walletName = (await SeedStorage.getActiveWalletMeta())?.name;
    _safeNotify();
  }

  /// Rename the ACTIVE wallet, then update provider
  Future<bool> renameActiveWallet(String newName) async {
    final id = await SeedStorage.getActiveWalletId();
    if (id == null) return false;
    final ok = await SeedStorage.renameWallet(id, newName);
    if (ok) {
      walletName = newName.trim();
      _safeNotify();
    }
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    stopRealtime();
    super.dispose();
  }

  // ---------- Helpers ----------
  bool _isStale(DateTime? last, Duration gap) =>
      last == null || DateTime.now().difference(last) >= gap;

  void _scheduleBalanceKick(Duration delay) {
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = Timer(delay, () => refresh(force: true));
  }
}
