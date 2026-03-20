import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/features/claimable/data/models/claimable_item.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';

class ClaimableVM extends ChangeNotifier {
  ClaimableVM({
    required StellarWalletServices service,
    required SeedKeypairVM seedVM,
    required WalletHomeVM walletHomeVM,
    required AssetVM assetVM,
  }) : _svc = service,
       _seedVM = seedVM,
       _walletHomeVM = walletHomeVM,
       _assetVM = assetVM {
    _walletHomeVM.addListener(_onWalletHomeStateChanged);
  }

  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;
  final WalletHomeVM _walletHomeVM;
  final AssetVM _assetVM;

  String? _accountId;
  String? get accountId => _accountId;

  List<ClaimableItem> _receivedItems = [];
  List<ClaimableItem> get receivedItems => List.unmodifiable(_receivedItems);

  List<ClaimableItem> _sentItems = [];
  List<ClaimableItem> get sentItems => List.unmodifiable(_sentItems);

  List<ClaimableItem> get allItems =>
      List.unmodifiable([..._receivedItems, ..._sentItems]);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _disposed = false;
  DateTime? _lastRefresh;
  DateTime? get lastRefresh => _lastRefresh;
  bool _refreshing = false;
  bool _refreshQueued = false;
  StreamSubscription<dynamic>? _accountStateSub;
  Timer? _refreshDebounce;
  Timer? _statusTimer;

  int _currentTab = 0;
  int get currentTab => _currentTab;

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      _safeNotify();
    }
  }

  List<ClaimableItem> get items {
    return _currentTab == 0 ? _receivedItems : _sentItems;
  }

  Iterable<AssetModel> get _claimableAssets =>
      _assetVM.assets.where((asset) => asset.chain.toLowerCase() == 'stellar');

  AssetModel? _resolveAsset(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;

    final direct = _assetVM.findAsset(trimmed);
    if (direct != null) return direct;

    for (final asset in _claimableAssets) {
      if (asset.matchesKey(trimmed)) return asset;
    }
    return null;
  }

  AssetModel? _assetForClaimableItem(ClaimableItem item) {
    final itemCode = item.assetCode.trim().toUpperCase();
    final itemIssuer = item.assetIssuer?.trim();

    for (final asset in _claimableAssets) {
      if (asset.isNative && itemCode == 'XLM') {
        return asset;
      }

      final candidateCode = (asset.assetCode ?? asset.symbol)
          .trim()
          .toUpperCase();
      if (candidateCode != itemCode) continue;

      final candidateIssuer = asset.issuer?.trim();
      if ((candidateIssuer ?? '').isEmpty || candidateIssuer == itemIssuer) {
        return asset;
      }
    }

    return null;
  }

  double getBalanceForSymbol(String symbol) {
    final asset = _resolveAsset(symbol);
    if (asset == null) return 0.0;
    return _walletHomeVM.state.balanceFor(asset.id);
  }

  bool hasSufficientBalance(String symbol, double amount) {
    return getBalanceForSymbol(symbol) >= amount;
  }

  void _onWalletHomeStateChanged() {
    if (_disposed) return;

    final newAccountId = _walletHomeVM.state.address;
    if (newAccountId != _accountId) {
      _accountId = newAccountId;
      _bindRealtime();

      if (_accountId != null && _accountId!.isNotEmpty) {
        unawaited(refresh());
      } else {
        _receivedItems = [];
        _sentItems = [];
        _cancelStatusTimer();
        _safeNotify();
      }
    }
  }

  bool _isSupportedAsset(ClaimableItem item) {
    return _assetForClaimableItem(item) != null;
  }

  int get receivedReadyCount =>
      _receivedItems.where((i) => i.canClaimNow && !i.isExpired).length;

  int get receivedLockedCount => _receivedItems
      .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
      .length;

  int get receivedExpiredCount =>
      _receivedItems.where((i) => i.isExpired).length;

  int get receivedTotalCount => _receivedItems.length;

  int get sentUnclaimedCount => _sentItems.length;

  int get sentReadyCount =>
      _sentItems.where((i) => i.canClaimNow && !i.isExpired).length;

  int get sentLockedCount => _sentItems
      .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
      .length;

  int get sentExpiredCount => _sentItems.where((i) => i.isExpired).length;

  int get currentTabCount =>
      _currentTab == 0 ? receivedTotalCount : sentUnclaimedCount;

  bool get hasReceivedItems => _receivedItems.isNotEmpty;

  bool get hasSentItems => _sentItems.isNotEmpty;

  bool get hasItems => items.isNotEmpty;

  Map<String, List<ClaimableItem>> get receivedItemsByStatus {
    return {
      'ready': _receivedItems
          .where((i) => i.canClaimNow && !i.isExpired)
          .toList(),
      'locked': _receivedItems
          .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
          .toList(),
      'expired': _receivedItems.where((i) => i.isExpired).toList(),
    };
  }

  Map<String, List<ClaimableItem>> get sentItemsByStatus {
    return {
      'ready': _sentItems.where((i) => i.canClaimNow && !i.isExpired).toList(),
      'locked': _sentItems
          .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
          .toList(),
      'reclaimable': _sentItems.where((i) => i.isExpired).toList(),
    };
  }

  Map<String, double> get receivedTotalsByAsset {
    final totals = <String, double>{};
    for (final item in _receivedItems) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  Map<String, double> get sentTotalsByAsset {
    final totals = <String, double>{};
    for (final item in _sentItems) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _walletHomeVM.removeListener(_onWalletHomeStateChanged);
    _accountStateSub?.cancel();
    _refreshDebounce?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    if (_loading) return;

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      _accountId = _walletHomeVM.state.address;

      if (_accountId == null || _accountId!.isEmpty) {
        final kp = await _seedVM.deriveKeyPair();
        _accountId = kp.accountId;
      }

      await _fetchAllBalances();
      _lastRefresh = DateTime.now();
      _bindRealtime();
      _scheduleStatusRefresh();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      if (kDebugMode) {
        print('[ClaimableVM] Init error: $e');
      }
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> refresh() async {
    if (_accountId == null || _accountId!.isEmpty) {
      return init();
    }

    if (_refreshing) {
      _refreshQueued = true;
      return;
    }

    _refreshing = true;

    _error = null;
    _safeNotify();

    try {
      await _fetchAllBalances();
      _lastRefresh = DateTime.now();
      _scheduleStatusRefresh();
    } catch (e) {
      _error = 'Refresh failed: $e';
      if (kDebugMode) {
        print('[ClaimableVM] Refresh error: $e');
      }
    } finally {
      _refreshing = false;
    }

    if (_refreshQueued && !_disposed) {
      _refreshQueued = false;
      unawaited(refresh());
    }

    _safeNotify();
  }

  Future<void> _fetchAllBalances() async {
    final aid = _accountId;
    if (aid == null || aid.isEmpty) {
      throw StateError('Account ID not set');
    }

    final results = await Future.wait([
      _fetchReceivedBalances(aid),
      _fetchSentBalances(aid),
    ]);

    _receivedItems = results[0];
    _sentItems = results[1];
    _recomputeStatuses();
  }

  void _bindRealtime() {
    _accountStateSub?.cancel();
    _accountStateSub = null;

    final aid = _accountId;
    if (aid == null || aid.isEmpty) {
      _cancelStatusTimer();
      return;
    }

    _accountStateSub = _svc
        .accountStateStream(aid)
        .listen(
          (_) => _scheduleRefresh(),
          onError: (Object error) {
            if (kDebugMode) {
              print('[ClaimableVM] Realtime stream error: $error');
            }
          },
          cancelOnError: false,
        );
  }

  void _scheduleRefresh([Duration delay = const Duration(milliseconds: 450)]) {
    if (_disposed) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(delay, () {
      if (_disposed) return;
      unawaited(refresh());
    });
  }

  void _cancelStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _scheduleStatusRefresh() {
    _cancelStatusTimer();

    final now = DateTime.now();
    DateTime? nextBoundary;

    for (final item in allItems) {
      final unlock = item.unlockTime;
      if (unlock != null && unlock.isAfter(now)) {
        if (nextBoundary == null || unlock.isBefore(nextBoundary)) {
          nextBoundary = unlock;
        }
      }

      final expiry = item.expiryTime;
      if (expiry != null && expiry.isAfter(now)) {
        if (nextBoundary == null || expiry.isBefore(nextBoundary)) {
          nextBoundary = expiry;
        }
      }
    }

    if (nextBoundary == null) return;

    final delay = nextBoundary.difference(now) + const Duration(seconds: 1);
    _statusTimer = Timer(delay, () {
      if (_disposed) return;
      _recomputeStatuses();
      _scheduleStatusRefresh();
      _scheduleRefresh(const Duration(milliseconds: 250));
      _safeNotify();
    });
  }

  void _recomputeStatuses() {
    final now = DateTime.now();

    _receivedItems = _receivedItems
        .map((item) => item.copyWith(canClaimNow: _canClaimNow(item, now)))
        .toList();
    _sortReceivedItems(_receivedItems);

    _sentItems = _sentItems
        .map((item) => item.copyWith(canClaimNow: _canClaimNow(item, now)))
        .toList();
    _sortSentItems(_sentItems);
  }

  bool _canClaimNow(ClaimableItem item, DateTime now) {
    final expiry = item.expiryTime;
    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    final unlock = item.unlockTime;
    if (unlock != null && now.isBefore(unlock)) {
      return false;
    }

    return true;
  }

  void _sortReceivedItems(List<ClaimableItem> items) {
    items.sort((a, b) {
      if (a.isExpired != b.isExpired) {
        return a.isExpired ? 1 : -1;
      }
      if (a.canClaimNow != b.canClaimNow) {
        return a.canClaimNow ? -1 : 1;
      }
      return b.amount.compareTo(a.amount);
    });
  }

  void _sortSentItems(List<ClaimableItem> items) {
    items.sort((a, b) {
      if (a.isExpired != b.isExpired) {
        return a.isExpired ? -1 : 1;
      }
      return b.amount.compareTo(a.amount);
    });
  }

  Future<List<ClaimableItem>> _fetchReceivedBalances(String accountId) async {
    final raw = await _svc.getClaimableBalances(accountId: accountId);
    final now = DateTime.now();

    final items = raw
        .map((r) => _parseResponse(r, accountId, now))
        .where(_isSupportedAsset)
        .toList();

    _sortReceivedItems(items);

    return items;
  }

  Future<List<ClaimableItem>> _fetchSentBalances(String accountId) async {
    final raw = await _svc.getSentClaimableBalances(accountId: accountId);
    final now = DateTime.now();

    final items = <ClaimableItem>[];

    for (final r in raw) {
      for (final claimant in r.claimants) {
        if (claimant.destination == accountId) continue;

        final parsed = _parsePredicate(claimant.predicate, now);

        final item = _parseSentResponse(
          r,
          claimant.destination,
          accountId,
          now,
          parsed,
        );

        if (_isSupportedAsset(item)) {
          items.add(item);
        }
      }
    }

    _sortSentItems(items);

    return items;
  }

  ClaimableItem _parseResponse(
    ClaimableBalanceResponse r,
    String myAccountId,
    DateTime now,
  ) {
    String assetCode;
    String? assetIssuer;

    final asset = r.asset;
    if (asset is AssetTypeNative) {
      assetCode = 'XLM';
    } else if (asset is AssetTypeCreditAlphaNum) {
      assetCode = asset.code;
      assetIssuer = asset.issuerId;
    } else {
      assetCode = 'XLM';
    }

    final amount = double.tryParse(r.amount) ?? 0.0;
    final sponsor = r.sponsor ?? '';

    DateTime? unlockTime;
    DateTime? expiryTime;
    bool canClaimNow = true;

    for (final c in r.claimants) {
      if (c.destination == myAccountId) {
        final parsed = _parsePredicate(c.predicate, now);
        unlockTime = parsed.unlockTime;
        expiryTime = parsed.expiryTime;
        canClaimNow = parsed.canClaimNow;
        break;
      }
    }

    DateTime? lastMod;
    try {
      if (r.lastModifiedTime != null) {
        lastMod = DateTime.tryParse(r.lastModifiedTime!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Error parsing lastModifiedTime: $e');
      }
    }

    return ClaimableItem(
      balanceId: r.balanceId,
      assetCode: assetCode,
      assetIssuer: assetIssuer,
      amount: amount,
      sponsorId: sponsor,
      lastModified: lastMod,
      unlockTime: unlockTime,
      expiryTime: expiryTime,
      canClaimNow: canClaimNow,
    );
  }

  ClaimableItem _parseSentResponse(
    ClaimableBalanceResponse r,
    String recipientId,
    String myAccountId,
    DateTime now,
    _PredicateResult predicateResult,
  ) {
    String assetCode;
    String? assetIssuer;

    final asset = r.asset;
    if (asset is AssetTypeNative) {
      assetCode = 'XLM';
    } else if (asset is AssetTypeCreditAlphaNum) {
      assetCode = asset.code;
      assetIssuer = asset.issuerId;
    } else {
      assetCode = 'XLM';
    }

    final amount = double.tryParse(r.amount) ?? 0.0;

    DateTime? lastMod;
    try {
      if (r.lastModifiedTime != null) {
        lastMod = DateTime.tryParse(r.lastModifiedTime!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Error parsing lastModifiedTime: $e');
      }
    }

    return ClaimableItem(
      balanceId: r.balanceId,
      assetCode: assetCode,
      assetIssuer: assetIssuer,
      amount: amount,
      sponsorId: recipientId,
      lastModified: lastMod,
      unlockTime: predicateResult.unlockTime,
      expiryTime: predicateResult.expiryTime,
      canClaimNow: predicateResult.canClaimNow,
    );
  }

  _PredicateResult _parsePredicate(ClaimantPredicateResponse p, DateTime now) {
    if (p.unconditional == true) {
      return const _PredicateResult(canClaimNow: true);
    }

    if (p.not != null) {
      final inner = p.not!;

      if (inner.beforeAbsoluteTime != null) {
        try {
          final unlock = DateTime.parse(inner.beforeAbsoluteTime!);
          return _PredicateResult(
            canClaimNow: now.isAfter(unlock),
            unlockTime: unlock,
          );
        } catch (e) {
          if (kDebugMode) {
            print('[ClaimableVM] Error parsing NOT beforeAbsoluteTime: $e');
          }
        }
      }

      final nested = _parsePredicate(inner, now);
      return _PredicateResult(
        canClaimNow: !nested.canClaimNow,
        unlockTime: nested.unlockTime,
        expiryTime: nested.expiryTime,
      );
    }

    if (p.beforeAbsoluteTime != null) {
      try {
        final deadline = DateTime.parse(p.beforeAbsoluteTime!);
        return _PredicateResult(
          canClaimNow: now.isBefore(deadline),
          expiryTime: deadline,
        );
      } catch (e) {
        if (kDebugMode) {
          print('[ClaimableVM] Error parsing beforeAbsoluteTime: $e');
        }
      }
    }

    if (p.beforeRelativeTime != null) {
      return const _PredicateResult(canClaimNow: true);
    }

    if (p.and != null && p.and!.isNotEmpty) {
      bool allTrue = true;
      DateTime? unlock;
      DateTime? expiry;

      for (final sub in p.and!) {
        final r = _parsePredicate(sub, now);
        if (!r.canClaimNow) allTrue = false;

        if (r.unlockTime != null) {
          if (unlock == null || r.unlockTime!.isAfter(unlock)) {
            unlock = r.unlockTime;
          }
        }
        if (r.expiryTime != null) {
          if (expiry == null || r.expiryTime!.isBefore(expiry)) {
            expiry = r.expiryTime;
          }
        }
      }

      return _PredicateResult(
        canClaimNow: allTrue,
        unlockTime: unlock,
        expiryTime: expiry,
      );
    }

    if (p.or != null && p.or!.isNotEmpty) {
      bool anyTrue = false;
      DateTime? earliestUnlock;
      DateTime? latestExpiry;

      for (final sub in p.or!) {
        final r = _parsePredicate(sub, now);
        if (r.canClaimNow) anyTrue = true;
        if (r.unlockTime != null) {
          if (earliestUnlock == null ||
              r.unlockTime!.isBefore(earliestUnlock)) {
            earliestUnlock = r.unlockTime;
          }
        }
        if (r.expiryTime != null) {
          if (latestExpiry == null || r.expiryTime!.isAfter(latestExpiry)) {
            latestExpiry = r.expiryTime;
          }
        }
      }
      return _PredicateResult(
        canClaimNow: anyTrue,
        unlockTime: earliestUnlock,
        expiryTime: latestExpiry,
      );
    }

    return const _PredicateResult(canClaimNow: true);
  }

  Future<String> claim(String balanceId) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.claimClaimableBalance(
        keyPair: kp,
        balanceId: balanceId,
      );

      _receivedItems.removeWhere((i) => i.balanceId == balanceId);
      _safeNotify();

      _walletHomeVM.refresh(force: true);

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Claim error: $e');
      }
      rethrow;
    }
  }

  Future<String> reclaim(String balanceId) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.claimClaimableBalance(
        keyPair: kp,
        balanceId: balanceId,
      );

      _sentItems.removeWhere((i) => i.balanceId == balanceId);
      _safeNotify();

      _walletHomeVM.refresh(force: true);

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Reclaim error: $e');
      }
      rethrow;
    }
  }

  Asset _assetFromSymbol(String symbol) {
    final asset = _resolveAsset(symbol);
    if (asset == null) {
      throw StateError('Unsupported asset: $symbol');
    }

    if (asset.isNative) return Asset.NATIVE;

    final code = (asset.assetCode ?? asset.symbol).trim();
    final issuer = asset.issuer?.trim();
    if (code.isEmpty || issuer == null || issuer.isEmpty) {
      throw StateError('Asset is missing Stellar issuer metadata: ${asset.id}');
    }

    return code.length <= 4
        ? AssetTypeCreditAlphaNum4(code, issuer)
        : AssetTypeCreditAlphaNum12(code, issuer);
  }

  Future<String> createUnconditional({
    required String assetSymbol,
    required double amount,
    required String recipientId,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.createUnconditionalClaimableBalance(
        keyPair: kp,
        asset: _assetFromSymbol(assetSymbol),
        amount: amount,
        recipientId: recipientId,
      );

      _walletHomeVM.refresh(force: true);
      refresh();

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create unconditional error: $e');
      }
      rethrow;
    }
  }

  Future<String> createUnconditionalWithExpiry({
    required String assetSymbol,
    required double amount,
    required String recipientId,
    required DateTime expiryTime,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.createUnconditionalWithExpiry(
        keyPair: kp,
        asset: _assetFromSymbol(assetSymbol),
        amount: amount,
        recipientId: recipientId,
        expiryTime: expiryTime,
      );

      _walletHomeVM.refresh(force: true);
      refresh();

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create unconditional with expiry error: $e');
      }
      rethrow;
    }
  }

  Future<String> createTimeLocked({
    required String assetSymbol,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.createTimeLockedPayment(
        keyPair: kp,
        asset: _assetFromSymbol(assetSymbol),
        amount: amount,
        recipientId: recipientId,
        unlockTime: unlockTime,
      );

      _walletHomeVM.refresh(force: true);
      refresh();

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create time-locked error: $e');
      }
      rethrow;
    }
  }

  Future<String> createTimeLockedWithExpiry({
    required String assetSymbol,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    required DateTime expiryTime,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.createTimeLockedWithExpiry(
        keyPair: kp,
        asset: _assetFromSymbol(assetSymbol),
        amount: amount,
        recipientId: recipientId,
        unlockTime: unlockTime,
        expiryTime: expiryTime,
      );

      _walletHomeVM.refresh(force: true);
      refresh();

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create time-locked with expiry error: $e');
      }
      rethrow;
    }
  }

  Future<bool> hasTrustline(String symbol) async {
    try {
      final aid = _accountId ?? _walletHomeVM.state.address;
      if (aid == null || aid.isEmpty) return false;

      return await _svc.hasTrustline(aid, _assetFromSymbol(symbol));
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Check trustline error: $e');
      }
      return false;
    }
  }

  Future<bool> hasUsdcTrustline() => hasTrustline('USDC');
}

class _PredicateResult {
  final bool canClaimNow;

  final DateTime? unlockTime;

  final DateTime? expiryTime;

  const _PredicateResult({
    required this.canClaimNow,
    this.unlockTime,
    this.expiryTime,
  });
}
