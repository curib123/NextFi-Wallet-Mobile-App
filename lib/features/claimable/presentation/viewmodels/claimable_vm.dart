// lib/features/claimable/view_model/claimable_vm.dart
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

/// View model for managing claimable balances.
///
/// Handles fetching, parsing, and claiming of Stellar claimable balances.
/// Supports both received (claimable by user) and sent (created by user) balances.
/// Supports expiration predicates for both instant and time-locked modes.
///
/// Filters claimable balances to assets supported by AssetVM.
///
/// **Best Practice**: Uses WalletHomeVM for balance retrieval to ensure
/// consistency and avoid redundant API calls.
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
    // Listen to wallet home state changes for balance updates
    _walletHomeVM.addListener(_onWalletHomeStateChanged);
  }

  final StellarWalletServices _svc;
  final SeedKeypairVM _seedVM;
  final WalletHomeVM _walletHomeVM;
  final AssetVM _assetVM;

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // State
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
  bool _refreshing = false;
  bool _refreshQueued = false;
  StreamSubscription<dynamic>? _accountStateSub;
  Timer? _refreshDebounce;
  Timer? _statusTimer;

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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Balance access via WalletHomeVM
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

  /// Get balance for a given asset symbol
  double getBalanceForSymbol(String symbol) {
    final asset = _resolveAsset(symbol);
    if (asset == null) return 0.0;
    return _walletHomeVM.state.balanceFor(asset.id);
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
      _bindRealtime();

      // Refresh claimable balances when account changes
      if (_accountId != null && _accountId!.isNotEmpty) {
        unawaited(refresh());
      } else {
        // Clear items if no account
        _receivedItems = [];
        _sentItems = [];
        _cancelStatusTimer();
        _safeNotify();
      }
    }
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Filtering helpers
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  bool _isSupportedAsset(ClaimableItem item) {
    return _assetForClaimableItem(item) != null;
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Computed properties
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  /// Number of claimable (ready) received items Ã¢â‚¬â€ excludes expired
  int get receivedReadyCount =>
      _receivedItems.where((i) => i.canClaimNow && !i.isExpired).length;

  /// Number of locked received items Ã¢â‚¬â€ excludes expired
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
          .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
          .toList(),
      'expired': _receivedItems.where((i) => i.isExpired).toList(),
    };
  }

  /// Get sent items grouped by status
  Map<String, List<ClaimableItem>> get sentItemsByStatus {
    return {
      'ready': _sentItems.where((i) => i.canClaimNow && !i.isExpired).toList(),
      'locked': _sentItems
          .where((i) => i.unlockTime != null && !i.canClaimNow && !i.isExpired)
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Lifecycle
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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
    _accountStateSub?.cancel();
    _refreshDebounce?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Init & Refresh
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

  /// Refresh the claimable balances list
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

  /// Fetch balances that can be claimed by this account
  ///
  /// Filters to claimable assets supported by AssetVM.
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

  /// Fetch balances created/sponsored by this account
  ///
  /// Filters to claimable assets supported by AssetVM.
  Future<List<ClaimableItem>> _fetchSentBalances(String accountId) async {
    final raw = await _svc.getSentClaimableBalances(accountId: accountId);
    final now = DateTime.now();

    final items = <ClaimableItem>[];

    for (final r in raw) {
      for (final claimant in r.claimants) {
        // Skip the sender's own claimant entry (used for reclaim after expiry)
        if (claimant.destination == accountId) continue;

        final parsed = _parsePredicate(claimant.predicate, now);

        final item = _parseSentResponse(
          r,
          claimant.destination,
          accountId,
          now,
          parsed,
        );

        // Ã¢â€ Â FILTER: Only add XLM and USDC items
        if (_isSupportedAsset(item)) {
          items.add(item);
        }
      }
    }

    _sortSentItems(items);

    return items;
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Parsing Ã¢â‚¬â€ uses SDK v3 types
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  /// Parse a ClaimableBalanceResponse into a ClaimableItem (received)
  ClaimableItem _parseResponse(
    ClaimableBalanceResponse r,
    String myAccountId,
    DateTime now,
  ) {
    // Ã¢â€â‚¬Ã¢â€â‚¬ Asset Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

    // Ã¢â€â‚¬Ã¢â€â‚¬ Claimant predicate Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

    // Ã¢â€â‚¬Ã¢â€â‚¬ Last modified Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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
    // Ã¢â€â‚¬Ã¢â€â‚¬ Asset Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

    // Ã¢â€â‚¬Ã¢â€â‚¬ Last modified Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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
  /// - `unconditional` Ã¢â€ â€™ always claimable, no times
  /// - `beforeAbsoluteTime(T)` Ã¢â€ â€™ claimable before T (expiry = T)
  /// - `NOT(beforeAbsoluteTime(T))` Ã¢â€ â€™ claimable after T (unlock = T)
  /// - `AND(NOT(before(unlock)), before(expiry))` Ã¢â€ â€™ window between unlock & expiry
  /// - `OR(...)` Ã¢â€ â€™ at least one must be true
  _PredicateResult _parsePredicate(ClaimantPredicateResponse p, DateTime now) {
    // 1) Unconditional Ã¢â‚¬â€ always claimable
    if (p.unconditional == true) {
      return const _PredicateResult(canClaimNow: true);
    }

    // 2) NOT(beforeAbsoluteTime) Ã¢â€ â€™ can claim AFTER that time (unlock)
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

      // NOT applied to something else Ã¢â‚¬â€ recurse and invert
      final nested = _parsePredicate(inner, now);
      return _PredicateResult(
        canClaimNow: !nested.canClaimNow,
        unlockTime: nested.unlockTime,
        expiryTime: nested.expiryTime,
      );
    }

    // 3) beforeAbsoluteTime Ã¢â€ â€™ can claim BEFORE the deadline (expiry)
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

    // 4) beforeRelativeTime Ã¢â‚¬â€ relative seconds from creation
    //    We can't fully evaluate without creation time; treat as claimable.
    if (p.beforeRelativeTime != null) {
      return const _PredicateResult(canClaimNow: true);
    }

    // 5) AND Ã¢â‚¬â€ all sub-predicates must be true
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

    // 6) OR Ã¢â‚¬â€ at least one sub-predicate must be true
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

    // Fallback Ã¢â‚¬â€ assume claimable if we can't fully parse
    return const _PredicateResult(canClaimNow: true);
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Claim / Reclaim
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Create
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  /// Get the correct asset based on symbol
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

  /// Create an unconditional claimable balance (recipient can claim anytime).
  /// No expiration Ã¢â‚¬â€ stays claimable forever.
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
  /// No expiration Ã¢â‚¬â€ once unlocked, stays claimable forever.
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Trustline Check
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

