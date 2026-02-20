import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:next_fi/services/wallet/models/wallet_dtos.dart';
import 'package:next_fi/services/wallet/models/wallet_models.dart';

/// Unified wallet manager that coordinates local seed storage with backend sync.
///
/// Architecture:
/// - Local (SeedStorage): Secure seed phrases (NEVER sent to backend)
/// - Backend (WalletCoreService): Public addresses & labels (synced across devices)
///
/// Workflow:
/// 1. Create/Import wallet → Save seed locally + Register public address to backend
/// 2. Switch wallet → Load from local + Verify backend sync
/// 3. Delete wallet → Remove from local + Backend
/// 4. Rename wallet → Update local + Backend
class WalletManager {
  WalletManager._();
  static final WalletManager I = WalletManager._();

  final _api = WalletCoreService.I;

  Future<List<WalletAddress>> _listBackendWallets({
    String? q,
    String? network,
  }) async {
    final wallets = <WalletAddress>[];
    var page = 1;

    while (true) {
      final response = await _api.listPaged(
        query: WalletListQuery(q: q, network: network, page: page, limit: 100),
      );

      wallets.addAll(response.items);

      final totalPages = response.meta.totalPages < 1
          ? 1
          : response.meta.totalPages;
      if (page >= totalPages || response.items.isEmpty) {
        break;
      }
      page += 1;
    }

    return wallets;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE / IMPORT WALLET
  // ─────────────────────────────────────────────────────────────────────────

  /// Create a new wallet with backend sync
  ///
  /// Steps:
  /// 1. Save seed locally (secure)
  /// 2. Register public address to backend (or reconnect if already exists)
  /// 3. Update local metadata with backend wallet ID
  Future<WalletCreationResult> createWallet({
    required String mnemonic,
    required String publicAddress,
    String? name,
    bool makeActive = true,
  }) async {
    try {
      // Step 1: Save seed locally first (most critical)
      final localId = await SeedStorage.addWallet(
        mnemonic,
        name: name,
        publicAddress: publicAddress,
        makeActive: makeActive,
      );

      // Step 2: Register to backend OR reconnect if already exists
      String? backendId;
      bool reconnected = false;

      try {
        // Try to create new wallet
        final backendWallet = await _api.create(
          publicAddress: publicAddress,
          label: name ?? 'Wallet ${DateTime.now().millisecondsSinceEpoch}',
          network: 'stellar',
        );
        backendId = backendWallet.id;
      } catch (e) {
        // If creation failed, check if it's because wallet already exists
        print('[WalletManager] Backend creation failed: $e');

        try {
          // Try to find existing wallet with this address
          final backendWallets = await _listBackendWallets(
            q: publicAddress,
            network: 'stellar',
          );
          final existing = backendWallets.firstWhereOrNull(
            (w) => w.publicAddress == publicAddress,
          );

          if (existing != null) {
            // Wallet already exists in backend - reconnect to it
            backendId = existing.id;
            reconnected = true;
            print(
              '[WalletManager] Reconnected to existing backend wallet: ${existing.label}',
            );

            // Optionally update the label if it's different
            if (name != null && name != existing.label) {
              try {
                await _api.updateLabel(walletId: existing.id, label: name);
              } catch (_) {
                // Label update failed, not critical
              }
            }
          }
        } catch (listError) {
          print('[WalletManager] Failed to check existing wallets: $listError');
        }
      }

      return WalletCreationResult(
        localId: localId,
        backendId: backendId,
        publicAddress: publicAddress,
        syncedToBackend: backendId != null,
        reconnected: reconnected,
      );
    } catch (e) {
      throw WalletException('Failed to create wallet: $e');
    }
  }

  /// Import existing wallet with backend sync
  Future<WalletCreationResult> importWallet({
    required String mnemonic,
    required String publicAddress,
    String? name,
    bool makeActive = true,
  }) async {
    // Same logic as createWallet
    return createWallet(
      mnemonic: mnemonic,
      publicAddress: publicAddress,
      name: name,
      makeActive: makeActive,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIST WALLETS (MERGED VIEW)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all wallets (local + backend sync status)
  Future<List<WalletViewModel>> listWallets() async {
    // Get local wallets (authoritative source)
    final localWallets = await SeedStorage.listWallets();

    // Get backend wallets (for sync status)
    List<WalletAddress>? backendWallets;
    try {
      backendWallets = await _listBackendWallets();
    } catch (e) {
      print('[WalletManager] Backend fetch failed: $e');
      // Continue with local-only data
    }

    // Merge data
    final activeId = await SeedStorage.getActiveWalletId();

    return localWallets.map((local) {
      // Find matching backend wallet by public address
      final backend = backendWallets?.firstWhereOrNull(
        (b) => b.publicAddress == local.publicAddress,
      );

      return WalletViewModel(
        localId: local.id,
        backendId: backend?.id,
        name: local.name,
        publicAddress: local.publicAddress,
        createdAt: local.createdAt,
        lastUsedAt: local.lastUsedAt,
        isActive: local.id == activeId,
        syncedToBackend: backend != null,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE WALLET
  // ─────────────────────────────────────────────────────────────────────────

  /// Rename wallet (local + backend)
  Future<bool> renameWallet({
    required String localId,
    required String newName,
  }) async {
    try {
      // Update local first
      final localSuccess = await SeedStorage.renameWallet(localId, newName);
      if (!localSuccess) return false;

      // Get public address to find backend wallet
      final meta = await SeedStorage.getActiveWalletMeta();
      if (meta?.publicAddress == null) return localSuccess;

      // Update backend (best effort)
      try {
        final backendWallets = await _listBackendWallets();
        final backendWallet = backendWallets.firstWhereOrNull(
          (w) => w.publicAddress == meta!.publicAddress,
        );

        if (backendWallet != null) {
          await _api.updateLabel(walletId: backendWallet.id, label: newName);
        }
      } catch (e) {
        print('[WalletManager] Backend update failed: $e');
      }

      return true;
    } catch (e) {
      throw WalletException('Failed to rename wallet: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE WALLET
  // ─────────────────────────────────────────────────────────────────────────

  /// Delete wallet (local + backend)
  Future<bool> deleteWallet({required String localId}) async {
    try {
      // Get wallet info before deletion
      final wallets = await listWallets();
      final wallet = wallets.firstWhereOrNull((w) => w.localId == localId);

      if (wallet == null) {
        throw WalletException('Wallet not found');
      }

      // Delete from backend first (can retry if fails)
      if (wallet.backendId != null) {
        try {
          await _api.remove(walletId: wallet.backendId!);
        } catch (e) {
          print('[WalletManager] Backend deletion failed: $e');
          // Continue with local deletion
        }
      }

      // Delete from local storage
      final success = await SeedStorage.removeWallet(localId);
      return success;
    } catch (e) {
      throw WalletException('Failed to delete wallet: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SWITCH WALLET
  // ─────────────────────────────────────────────────────────────────────────

  /// Switch active wallet
  Future<bool> switchWallet({required String localId}) async {
    return await SeedStorage.setActiveWallet(localId);
  }

  /// Get active wallet
  Future<WalletViewModel?> getActiveWallet() async {
    final wallets = await listWallets();
    return wallets.firstWhereOrNull((w) => w.isActive);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Sync local wallets to backend (reconciliation)
  Future<SyncResult> syncToBackend() async {
    int created = 0;
    int updated = 0;
    int failed = 0;

    try {
      final localWallets = await SeedStorage.listWallets();
      final backendWallets = await _listBackendWallets();

      for (final local in localWallets) {
        if (local.publicAddress == null) continue;

        // Check if already exists in backend
        final exists = backendWallets.any(
          (b) => b.publicAddress == local.publicAddress,
        );

        if (!exists) {
          // Create in backend
          try {
            await _api.create(
              publicAddress: local.publicAddress!,
              label: local.name,
              network: 'stellar',
            );
            created++;
          } catch (e) {
            print('[WalletManager] Sync failed for ${local.name}: $e');
            failed++;
          }
        } else {
          // Update label if different
          final backend = backendWallets.firstWhere(
            (b) => b.publicAddress == local.publicAddress,
          );

          if (backend.label != local.name) {
            try {
              await _api.updateLabel(walletId: backend.id, label: local.name);
              updated++;
            } catch (e) {
              print('[WalletManager] Update failed for ${local.name}: $e');
              failed++;
            }
          }
        }
      }

      return SyncResult(
        created: created,
        updated: updated,
        failed: failed,
        success: failed == 0,
      );
    } catch (e) {
      throw WalletException('Sync failed: $e');
    }
  }

  /// Pull wallets from backend (for multi-device sync)
  /// WARNING: This does NOT sync seeds (they never leave the device)
  Future<List<CloudWallet>> pullFromBackend() async {
    try {
      final backendWallets = await _listBackendWallets();
      final localWallets = await SeedStorage.listWallets();

      final cloudOnlyWallets = <CloudWallet>[];

      for (final backend in backendWallets) {
        // Check if this public address exists locally
        final exists = localWallets.any(
          (l) => l.publicAddress == backend.publicAddress,
        );

        if (!exists) {
          // This wallet exists on backend but not locally
          cloudOnlyWallets.add(
            CloudWallet(
              backendId: backend.id,
              publicAddress: backend.publicAddress,
              label: backend.label ?? 'Wallet',
              needsImport: true,
            ),
          );
        }
      }

      return cloudOnlyWallets;
    } catch (e) {
      throw WalletException('Pull from backend failed: $e');
    }
  }

  /// Get complete wallet overview (local + cloud-only)
  /// This is what you should use on login to show all wallets
  ///
  /// IMPORTANT: This also auto-syncs local wallets to backend
  Future<WalletOverview> getWalletOverview({bool autoSync = true}) async {
    try {
      // Auto-sync local wallets to backend (if enabled)
      if (autoSync) {
        await _autoSyncLocalWallets();
      }

      // Get local wallets with seeds
      final localWallets = await listWallets();

      // Get cloud-only wallets (no seeds)
      final cloudOnlyWallets = await pullFromBackend();

      return WalletOverview(
        localWallets: localWallets,
        cloudOnlyWallets: cloudOnlyWallets,
        hasLocalWallets: localWallets.isNotEmpty,
        hasCloudOnlyWallets: cloudOnlyWallets.isNotEmpty,
      );
    } catch (e) {
      throw WalletException('Failed to get wallet overview: $e');
    }
  }

  /// Auto-sync local wallets to backend (silent, best-effort)
  /// This ensures all local wallets are registered in the backend
  Future<void> _autoSyncLocalWallets() async {
    try {
      final localWallets = await SeedStorage.listWallets();

      // Get existing backend wallets
      List<WalletAddress> backendWallets = [];
      try {
        backendWallets = await _listBackendWallets();
      } catch (e) {
        print('[WalletManager] Backend list failed during auto-sync: $e');
        return; // Can't sync if we can't fetch backend wallets
      }

      // Sync each local wallet to backend
      for (final local in localWallets) {
        if (local.publicAddress == null) continue;

        // Check if already exists in backend
        final exists = backendWallets.any(
          (b) => b.publicAddress == local.publicAddress,
        );

        if (!exists) {
          // Create in backend (silent, best-effort)
          try {
            await _api.create(
              publicAddress: local.publicAddress!,
              label: local.name,
              network: 'stellar',
            );
            print('[WalletManager] Auto-synced wallet: ${local.name}');
          } catch (e) {
            // Silent failure - don't block the UI
            print('[WalletManager] Auto-sync failed for ${local.name}: $e');
          }
        }
      }
    } catch (e) {
      // Silent failure - auto-sync is best-effort
      print('[WalletManager] Auto-sync error: $e');
    }
  }

  /// Check if a specific public address has a local seed
  Future<bool> hasLocalSeed(String publicAddress) async {
    final localWallets = await SeedStorage.listWallets();
    return localWallets.any((w) => w.publicAddress == publicAddress);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Extension for null-safe firstWhere
// ─────────────────────────────────────────────────────────────────────────

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────

class WalletCreationResult {
  final String localId;
  final String? backendId;
  final String publicAddress;
  final bool syncedToBackend;
  final bool reconnected; // True if reconnected to existing backend wallet

  WalletCreationResult({
    required this.localId,
    this.backendId,
    required this.publicAddress,
    required this.syncedToBackend,
    this.reconnected = false,
  });
}

class WalletViewModel {
  final String localId;
  final String? backendId;
  final String name;
  final String? publicAddress;
  final String createdAt;
  final String? lastUsedAt;
  final bool isActive;
  final bool syncedToBackend;

  WalletViewModel({
    required this.localId,
    this.backendId,
    required this.name,
    this.publicAddress,
    required this.createdAt,
    this.lastUsedAt,
    required this.isActive,
    required this.syncedToBackend,
  });
}

/// Wallet that exists in backend but has no local seed
class CloudWallet {
  final String backendId;
  final String publicAddress;
  final String label;
  final bool needsImport;

  CloudWallet({
    required this.backendId,
    required this.publicAddress,
    required this.label,
    this.needsImport = true,
  });
}

/// Complete overview of all wallets (local + cloud-only)
class WalletOverview {
  final List<WalletViewModel> localWallets; // Wallets with seeds
  final List<CloudWallet>
  cloudOnlyWallets; // Wallets without seeds (need import)
  final bool hasLocalWallets;
  final bool hasCloudOnlyWallets;

  WalletOverview({
    required this.localWallets,
    required this.cloudOnlyWallets,
    required this.hasLocalWallets,
    required this.hasCloudOnlyWallets,
  });

  int get totalWallets => localWallets.length + cloudOnlyWallets.length;
  bool get hasAnyWallets => hasLocalWallets || hasCloudOnlyWallets;
}

class SyncResult {
  final int created;
  final int updated;
  final int failed;
  final bool success;

  SyncResult({
    required this.created,
    required this.updated,
    required this.failed,
    required this.success,
  });
}

class WalletException implements Exception {
  final String message;
  WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}
