// lib/features/claimable/view_model/claimable_vm.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

/// View model for managing claimable balances.
///
/// Handles fetching, parsing, and claiming of Stellar claimable balances.
/// Supports both received (claimable by user) and sent (created by user) balances.
class ClaimableVM extends ChangeNotifier {
  ClaimableVM({
    required StellarWalletServices service,
    required SeedKeypairVM seedVM,
  })  : _svc = service,
        _seedVM = seedVM;

  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;

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
  // Computed properties
  // ──────────────────────────────────────────────────────────────────────────

  /// Number of claimable (ready) received items
  int get receivedReadyCount =>
      _receivedItems.where((i) => i.canClaimNow).length;

  /// Number of locked received items
  int get receivedLockedCount =>
      _receivedItems.where((i) => i.unlockTime != null && !i.canClaimNow).length;

  /// Total received count
  int get receivedTotalCount => _receivedItems.length;

  /// Number of unclaimed sent items
  int get sentUnclaimedCount => _sentItems.length;

  /// Number of sent items that are ready to claim (by recipients)
  int get sentReadyCount =>
      _sentItems.where((i) => i.canClaimNow).length;

  /// Number of sent items that are locked
  int get sentLockedCount =>
      _sentItems.where((i) => i.unlockTime != null && !i.canClaimNow).length;

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
      'ready': _receivedItems.where((i) => i.canClaimNow).toList(),
      'locked': _receivedItems.where((i) => i.unlockTime != null && !i.canClaimNow).toList(),
    };
  }

  /// Get sent items grouped by status
  Map<String, List<ClaimableItem>> get sentItemsByStatus {
    return {
      'ready': _sentItems.where((i) => i.canClaimNow).toList(),
      'locked': _sentItems.where((i) => i.unlockTime != null && !i.canClaimNow).toList(),
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
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Init & Refresh
  // ──────────────────────────────────────────────────────────────────────────

  /// Initialize the view model and load balances
  Future<void> init() async {
    if (_loading) return; // Prevent concurrent initialization

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final kp = await _seedVM.deriveKeyPair();
      _accountId = kp.accountId;
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
    if (_accountId == null) {
      return init();
    }

    if (_loading) return; // Prevent concurrent refreshes

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

    // Fetch both received and sent balances in parallel
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

    // Sort: claimable-now first, then by amount descending
    items.sort((a, b) {
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
      // Parse each claimant to determine who can claim and when
      for (final claimant in r.claimants) {
        // Skip if claimant is the sender (shouldn't happen, but just in case)
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

    // Sort by amount descending
    items.sort((a, b) => b.amount.compareTo(a.amount));

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
    bool canClaimNow = true;

    for (final c in r.claimants) {
      if (c.destination == myAccountId) {
        final parsed = _parsePredicate(c.predicate, now);
        unlockTime = parsed.unlockTime;
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
      canClaimNow: predicateResult.canClaimNow,
    );
  }

  /// Recursively evaluate a ClaimantPredicateResponse to determine
  /// whether the balance can be claimed right now and extract any
  /// unlock/deadline timestamp.
  _PredicateResult _parsePredicate(
      ClaimantPredicateResponse p,
      DateTime now,
      ) {
    // 1) Unconditional — always claimable
    if (p.unconditional == true) {
      return const _PredicateResult(canClaimNow: true);
    }

    // 2) NOT(beforeAbsoluteTime) → can claim AFTER that time
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
      );
    }

    // 3) beforeAbsoluteTime → can claim BEFORE the deadline
    if (p.beforeAbsoluteTime != null) {
      try {
        final deadline = DateTime.parse(p.beforeAbsoluteTime!);
        return _PredicateResult(
          canClaimNow: now.isBefore(deadline),
          unlockTime: deadline,
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
    if (p.and != null && p.and!.isNotEmpty) {
      bool allTrue = true;
      DateTime? latestUnlock;

      for (final sub in p.and!) {
        final r = _parsePredicate(sub, now);
        if (!r.canClaimNow) allTrue = false;
        if (r.unlockTime != null) {
          if (latestUnlock == null || r.unlockTime!.isAfter(latestUnlock)) {
            latestUnlock = r.unlockTime;
          }
        }
      }
      return _PredicateResult(
        canClaimNow: allTrue,
        unlockTime: latestUnlock,
      );
    }

    // 6) OR — at least one sub-predicate must be true
    if (p.or != null && p.or!.isNotEmpty) {
      bool anyTrue = false;
      DateTime? earliestUnlock;

      for (final sub in p.or!) {
        final r = _parsePredicate(sub, now);
        if (r.canClaimNow) anyTrue = true;
        if (r.unlockTime != null) {
          if (earliestUnlock == null ||
              r.unlockTime!.isBefore(earliestUnlock)) {
            earliestUnlock = r.unlockTime;
          }
        }
      }
      return _PredicateResult(
        canClaimNow: anyTrue,
        unlockTime: earliestUnlock,
      );
    }

    // Fallback — assume claimable if we can't fully parse
    return const _PredicateResult(canClaimNow: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Claim
  // ──────────────────────────────────────────────────────────────────────────

  /// Claim a claimable balance by ID
  ///
  /// Returns the transaction hash on success.
  /// Throws an exception on failure.
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

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Claim error: $e');
      }
      rethrow;
    }
  }

  /// Reclaim a sent claimable balance (if allowed by predicate)
  ///
  /// Note: This requires the sender to be a claimant, which is not
  /// typical but can be set up when creating the balance.
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

  /// Create an unconditional claimable balance (recipient can claim anytime).
  ///
  /// [isXlm] - true for XLM, false for USDC
  /// [amount] - amount to send
  /// [recipientId] - recipient's Stellar address
  /// [memo] - optional memo text
  ///
  /// Returns the transaction hash on success.
  Future<String> createUnconditional({
    required bool isXlm,
    required double amount,
    required String recipientId,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final asset = isXlm
          ? Asset.NATIVE
          : AssetTypeCreditAlphaNum4('USDC', _svc.usdcIssuer);

      return await _svc.createUnconditionalClaimableBalance(
        keyPair: kp,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create unconditional error: $e');
      }
      rethrow;
    }
  }

  /// Create a time-locked claimable balance.
  ///
  /// [isXlm] - true for XLM, false for USDC
  /// [amount] - amount to send
  /// [recipientId] - recipient's Stellar address
  /// [unlockTime] - when the recipient can claim
  /// [memo] - optional memo text
  ///
  /// Returns the transaction hash on success.
  Future<String> createTimeLocked({
    required bool isXlm,
    required double amount,
    required String recipientId,
    required DateTime unlockTime,
    String? memo,
  }) async {
    try {
      final kp = await _seedVM.deriveKeyPair();
      final asset = isXlm
          ? Asset.NATIVE
          : AssetTypeCreditAlphaNum4('USDC', _svc.usdcIssuer);

      return await _svc.createTimeLockedPayment(
        keyPair: kp,
        asset: asset,
        amount: amount,
        recipientId: recipientId,
        unlockTime: unlockTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Create time-locked error: $e');
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers for create screen
  // ──────────────────────────────────────────────────────────────────────────

  /// Get the current balance for XLM or USDC
  Future<double> getBalance(bool isXlm) async {
    try {
      final aid = _accountId ?? (await _seedVM.deriveKeyPair()).accountId;
      return isXlm
          ? await _svc.getXlmBalance(aid)
          : await _svc.getUsdcBalance(aid);
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Get balance error: $e');
      }
      return 0.0;
    }
  }

  /// Check if the account has a USDC trustline
  Future<bool> hasUsdcTrustline() async {
    try {
      final aid = _accountId ?? (await _seedVM.deriveKeyPair()).accountId;
      return await _svc.hasUsdcTrustline(aid);
    } catch (e) {
      if (kDebugMode) {
        print('[ClaimableVM] Check trustline error: $e');
      }
      return false;
    }
  }
}

/// Internal result type for predicate parsing
class _PredicateResult {
  final bool canClaimNow;
  final DateTime? unlockTime;

  const _PredicateResult({
    required this.canClaimNow,
    this.unlockTime,
  });
}