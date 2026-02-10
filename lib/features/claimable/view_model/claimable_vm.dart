// lib/features/claimable/view_model/claimable_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

/// View model for managing claimable balances.
///
/// Handles fetching, parsing, and claiming of Stellar claimable balances.
/// Supports both received (claimable by user) and sent (created by user) balances.
/// Supports expiration predicates for both instant and time-locked modes.
///
/// **Best Practice**: Uses WalletHomeVM for balance retrieval to ensure
/// consistency and avoid redundant API calls.
class ClaimableVM extends ChangeNotifier {
  ClaimableVM({
    required StellarWalletServices service,
    required SeedKeypairVM seedVM,
    required WalletHomeVM walletHomeVM,
  })  : _svc = service,
        _seedVM = seedVM,
        _walletHomeVM = walletHomeVM {
    // Listen to wallet home state changes for balance updates
    _walletHomeVM.addListener(_onWalletHomeStateChanged);
  }

  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;
  final WalletHomeVM _walletHomeVM;

  // ──────────────────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────────────────

  String? _accountId;
  String? get accountId => _accountId;

  /// Claimable balances that the user can claim (received)
  List<ClaimableItem> _receivedItems = [];
  List<ClaimableItem> get receivedItems => List.unmodifiable(_receivedItems);

  /// Claimable balances that the user has sent to others
  List<ClaimableItem> _sentItems = [];
  List<ClaimableItem> get sentItems => List.unmodifiable(_sentItems);

  /// Combined list of all items (received + sent)
  List<ClaimableItem> get allItems =>
      List.unmodifiable([..._receivedItems, ..._sentItems]);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _disposed = false;
  DateTime? _lastRefresh;
  DateTime? get lastRefresh => _lastRefresh;

  /// Current tab index (0 = received, 1 = sent)
  int _currentTab = 0;
  int get currentTab => _currentTab;

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      _safeNotify();
    }
  }

  /// Get items for current tab
  List<ClaimableItem> get items {
    return _currentTab == 0 ? _receivedItems : _sentItems;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Balance access via WalletHomeVM
  // ──────────────────────────────────────────────────────────────────────────

  /// Get current XLM balance from WalletHomeVM
  double get xlmBalance => _walletHomeVM.state.xlm;

  /// Get current USDC balance from WalletHomeVM
  double get usdcBalance => _walletHomeVM.state.usdc;

  /// Get balance for a given asset symbol
  double getBalanceForSymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'XLM':
        return xlmBalance;
      case 'USDC':
        return usdcBalance;
      default:
        return 0.0;
    }
  }

  /// Whether wallet has sufficient balance for amount (no reserve deduction)
  bool hasSufficientBalance(String symbol, double amount) {
    return getBalanceForSymbol(symbol) >= amount;
  }

  /// Listen to wallet home state changes
  void _onWalletHomeStateChanged() {
    if (_disposed) return;

    // Update account ID if it changed
    final newAccountId = _walletHomeVM.state.address;
    if (newAccountId != _accountId) {
      _accountId = newAccountId;

      // Refresh claimable balances when account changes
      if (_accountId != null && _accountId!.isNotEmpty) {
        refresh();
      } else {
        // Clear items if no account
        _receivedItems = [];
        _sentItems = [];
        _safeNotify();
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Computed properties
  // ──────────────────────────────────────────────────────────────────────────

  /// Number of claimable (ready) received items — excludes expired
  int get receivedReadyCount =>
      _receivedItems.where((i) => i.canClaimNow && !i.isExpired).length;

  /// Number of locked received items — excludes expired
  int get receivedLockedCount => _receivedItems
      .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
      .length;

  /// Number of expired received items
  int get receivedExpiredCount =>
      _receivedItems.where((i) => i.isExpired).length;

  /// Total received count
  int get receivedTotalCount => _receivedItems.length;

  /// Number of unclaimed sent items
  int get sentUnclaimedCount => _sentItems.length;

  /// Number of sent items that are ready to claim (by recipients)
  int get sentReadyCount =>
      _sentItems.where((i) => i.canClaimNow && !i.isExpired).length;

  /// Number of sent items that are locked
  int get sentLockedCount => _sentItems
      .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
      .length;

  /// Number of sent items that are expired (reclaimable by sender)
  int get sentExpiredCount => _sentItems.where((i) => i.isExpired).length;

  /// Total count of current tab
  int get currentTabCount =>
      _currentTab == 0 ? receivedTotalCount : sentUnclaimedCount;

  /// Whether there are any received items
  bool get hasReceivedItems => _receivedItems.isNotEmpty;

  /// Whether there are any sent items
  bool get hasSentItems => _sentItems.isNotEmpty;

  /// Whether current tab has items
  bool get hasItems => items.isNotEmpty;

  /// Get received items grouped by status
  Map<String, List<ClaimableItem>> get receivedItemsByStatus {
    return {
      'ready': _receivedItems
          .where((i) => i.canClaimNow && !i.isExpired)
          .toList(),
      'locked': _receivedItems
          .where(
              (i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
          .toList(),
      'expired': _receivedItems.where((i) => i.isExpired).toList(),
    };
  }

  /// Get sent items grouped by status
  Map<String, List<ClaimableItem>> get sentItemsByStatus {
    return {
      'ready': _sentItems
          .where((i) => i.canClaimNow && !i.isExpired)
          .toList(),
      'locked': _sentItems
          .where(
              (i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
          .toList(),
      'reclaimable': _sentItems.where((i) => i.isExpired).toList(),
    };
  }

  /// Get total amounts by asset (received only)
  Map<String, double> get receivedTotalsByAsset {
    final totals = <String, double>{};
    for (final item in _receivedItems) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  /// Get total amounts by asset (sent only)
  Map<String, double> get sentTotalsByAsset {
    final totals = <String, double>{};
    for (final item in _sentItems) {
      final asset = item.displayAsset;
      totals[asset] = (totals[asset] ?? 0.0) + item.amount;
    }
    return totals;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  /// Safely notify listeners, avoiding errors during build phase
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
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Init & Refresh
  // ──────────────────────────────────────────────────────────────────────────

  /// Initialize the view model and load balances
  Future<void> init() async {
    if (_loading) return;

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      // Get account ID from WalletHomeVM first (preferred)
      _accountId = _walletHomeVM.state.address;

      // Fallback to deriving from seed if not available
      if (_accountId == null || _accountId!.isEmpty) {
        final kp = await _seedVM.deriveKeyPair();
        _accountId = kp.accountId;
      }

      await _fetchAllBalances();
      _lastRefresh = DateTime.now();
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

  /// Refresh the claimable balances list
  Future<void> refresh() async {
    if (_accountId == null || _accountId!.isEmpty) {
      return init();
    }

    if (_loading) return;

    _error = null;
    _safeNotify();

    try {
      await _fetchAllBalances();
      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = 'Refresh failed: $e';
      if (kDebugMode) {
        print('[ClaimableVM] Refresh error: $e');
      }
    }
    _safeNotify();
  }

  /// Fetch all balances (received + sent)
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
  }

  /// Fetch balances that can be claimed by this account
  Future<List<ClaimableItem>> _fetchReceivedBalances(String accountId) async {
    final raw = await _svc.getClaimableBalances(accountId: accountId);
    final now = DateTime.now();

    final items = raw.map((r) => _parseResponse(r, accountId, now)).toList();

    // Sort: claimable-now first, then expired last, then by amount desc
    items.sort((a, b) {
      // Expired items go to the bottom
      if (a.isExpired != b.isExpired) {
        return a.isExpired ? 1 : -1;
      }
      // Then claimable-now first
      if (a.canClaimNow != b.canClaimNow) {
        return a.canClaimNow ? -1 : 1;
      }
      return b.amount.compareTo(a.amount);
    });

    return items;
  }

  /// Fetch balances created/sponsored by this account
  Future<List<ClaimableItem>> _fetchSentBalances(String accountId) async {
    final raw = await _svc.getSentClaimableBalances(accountId: accountId);
    final now = DateTime.now();

    final items = <ClaimableItem>[];

    for (final r in raw) {
      for (final claimant in r.claimants) {
        // Skip the sender's own claimant entry (used for reclaim after expiry)
        if (claimant.destination == accountId) continue;

        final parsed = _parsePredicate(claimant.predicate, now);

        items.add(_parseSentResponse(
          r,
          claimant.destination,
          accountId,
          now,
          parsed,
        ));
      }
    }

    // Sort: reclaimable (expired) first, then by amount desc
    items.sort((a, b) {
      if (a.isExpired != b.isExpired) {
        return a.isExpired ? -1 : 1;
      }
      return b.amount.compareTo(a.amount);
    });

    return items;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Parsing — uses SDK v3 types
  // ──────────────────────────────────────────────────────────────────────────

  /// Parse a ClaimableBalanceResponse into a ClaimableItem (received)
  ClaimableItem _parseResponse(
      ClaimableBalanceResponse r,
      String myAccountId,
      DateTime now,
      ) {
    // ── Asset ───────────────────────────────────────────────────────────
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

    // ── Claimant predicate ──────────────────────────────────────────────
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

    // ── Last modified ───────────────────────────────────────────────────
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

  /// Parse a ClaimableBalanceResponse into a ClaimableItem (sent)
  ClaimableItem _parseSentResponse(
      ClaimableBalanceResponse r,
      String recipientId,
      String myAccountId,
      DateTime now,
      _PredicateResult predicateResult,
      ) {
    // ── Asset ───────────────────────────────────────────────────────────
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

    // ── Last modified ───────────────────────────────────────────────────
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
      sponsorId: recipientId, // For sent items, show recipient as "sponsor"
      lastModified: lastMod,
      unlockTime: predicateResult.unlockTime,
      expiryTime: predicateResult.expiryTime,
      canClaimNow: predicateResult.canClaimNow,
    );
  }

  /// Recursively evaluate a ClaimantPredicateResponse to determine
  /// whether the balance can be claimed right now, and extract any
  /// unlock timestamp and/or expiry timestamp.
  ///
  /// Predicate patterns handled:
  /// - `unconditional` → always claimable, no times
  /// - `beforeAbsoluteTime(T)` → claimable before T (expiry = T)
  /// - `NOT(beforeAbsoluteTime(T))` → claimable after T (unlock = T)
  /// - `AND(NOT(before(unlock)), before(expiry))` → window between unlock & expiry
  /// - `OR(...)` → at least one must be true
  _PredicateResult _parsePredicate(
      ClaimantPredicateResponse p,
      DateTime now,
      ) {
    // 1) Unconditional — always claimable
    if (p.unconditional == true) {
      return const _PredicateResult(canClaimNow: true);
    }

    // 2) NOT(beforeAbsoluteTime) → can claim AFTER that time (unlock)
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

      // NOT applied to something else — recurse and invert
      final nested = _parsePredicate(inner, now);
      return _PredicateResult(
        canClaimNow: !nested.canClaimNow,
        unlockTime: nested.unlockTime,
        expiryTime: nested.expiryTime,
      );
    }

    // 3) beforeAbsoluteTime → can claim BEFORE the deadline (expiry)
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

    // 4) beforeRelativeTime — relative seconds from creation
    //    We can't fully evaluate without creation time; treat as claimable.
    if (p.beforeRelativeTime != null) {
      return const _PredicateResult(canClaimNow: true);
    }

    // 5) AND — all sub-predicates must be true
    //    Common pattern: AND(NOT(before(unlock)), before(expiry))
    if (p.and != null && p.and!.isNotEmpty) {
      bool allTrue = true;
      DateTime? unlock;
      DateTime? expiry;

      for (final sub in p.and!) {
        final r = _parsePredicate(sub, now);
        if (!r.canClaimNow) allTrue = false;

        // Collect unlock and expiry from sub-predicates
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

    // 6) OR — at least one sub-predicate must be true
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

    // Fallback — assume claimable if we can't fully parse
    return const _PredicateResult(canClaimNow: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Claim / Reclaim
  // ──────────────────────────────────────────────────────────────────────────

  /// Claim a claimable balance by ID
  ///
  /// Returns the transaction hash on success.
  /// Automatically refreshes wallet balances after claiming.
  Future<String> claim(String balanceId) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.claimClaimableBalance(
        keyPair: kp,
        balanceId: balanceId,
      );

      // Remove from local list immediately for responsive UI
      _receivedItems.removeWhere((i) => i.balanceId == balanceId);
      _safeNotify();

      // Refresh wallet balances in background (best practice)
      _walletHomeVM.refresh(force: true);

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Claim error: $e');
      }
      rethrow;
    }
  }

  /// Reclaim an expired sent claimable balance.
  ///
  /// This works because when creating with expiry, the sender is added
  /// as a claimant with NOT(beforeAbsoluteTime(expiry)) predicate,
  /// allowing them to claim after the expiry time.
  ///
  /// Returns the transaction hash on success.
  /// Automatically refreshes wallet balances after reclaiming.
  Future<String> reclaim(String balanceId) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final txHash = await _svc.claimClaimableBalance(
        keyPair: kp,
        balanceId: balanceId,
      );

      // Remove from local list immediately for responsive UI
      _sentItems.removeWhere((i) => i.balanceId == balanceId);
      _safeNotify();

      // Refresh wallet balances in background (best practice)
      _walletHomeVM.refresh(force: true);

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Reclaim error: $e');
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Create
  // ──────────────────────────────────────────────────────────────────────────

  /// Get the correct asset based on symbol
  Asset _assetFromSymbol(String symbol) {
    if (symbol.toUpperCase() == 'XLM') return Asset.NATIVE;
    if (symbol.toUpperCase() == 'USDC') {
      return AssetTypeCreditAlphaNum4('USDC', _svc.usdcIssuer);
    }
    return Asset.NATIVE;
  }

  /// Create an unconditional claimable balance (recipient can claim anytime).
  /// No expiration — stays claimable forever.
  /// Automatically refreshes wallet balances after creation.
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

      // Refresh wallet balances and claimable list in background
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

  /// Create an unconditional claimable balance **with expiration**.
  ///
  /// Recipient can claim immediately but must do so before [expiryTime].
  /// After expiry, the sender can reclaim the funds.
  /// Automatically refreshes wallet balances after creation.
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

      // Refresh wallet balances and claimable list in background
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

  /// Create a time-locked claimable balance.
  /// No expiration — once unlocked, stays claimable forever.
  /// Automatically refreshes wallet balances after creation.
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

      // Refresh wallet balances and claimable list in background
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

  /// Create a time-locked claimable balance **with expiration**.
  ///
  /// Recipient can only claim between [unlockTime] and [expiryTime].
  /// After expiry, the sender can reclaim the funds.
  /// Automatically refreshes wallet balances after creation.
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

      // Refresh wallet balances and claimable list in background
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

  // ──────────────────────────────────────────────────────────────────────────
  // USDC Trustline Check
  // ──────────────────────────────────────────────────────────────────────────

  /// Check if the account has a USDC trustline
  Future<bool> hasUsdcTrustline() async {
    try {
      final aid = _accountId ?? _walletHomeVM.state.address;
      if (aid == null || aid.isEmpty) return false;

      return await _svc.hasUsdcTrustline(aid);
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Check trustline error: $e');
      }
      return false;
    }
  }
}

/// Internal result type for predicate parsing.
///
/// Now carries both [unlockTime] (NOT before = claim after) and
/// [expiryTime] (before = claim before / deadline).
class _PredicateResult {
  final bool canClaimNow;

  /// The time after which claiming is allowed (from NOT(beforeAbsoluteTime))
  final DateTime? unlockTime;

  /// The deadline before which claiming must happen (from beforeAbsoluteTime)
  final DateTime? expiryTime;

  const _PredicateResult({
    required this.canClaimNow,
    this.unlockTime,
    this.expiryTime,
  });
}