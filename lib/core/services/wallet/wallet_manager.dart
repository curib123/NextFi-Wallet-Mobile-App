import 'package:flutter/foundation.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/wallet/wallet_core_service.dart';
import 'package:next_fi/core/services/wallet/models/wallet_dtos.dart';
import 'package:next_fi/core/services/wallet/models/wallet_models.dart';

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

  Future<WalletCreationResult> createWallet({
    required String mnemonic,
    required String publicAddress,
    String? name,
    bool makeActive = true,
  }) async {
    try {
      final localId = await SeedStorage.addWallet(
        mnemonic,
        name: name,
        publicAddress: publicAddress,
        makeActive: makeActive,
      );

      String? backendId;
      bool reconnected = false;

      try {
        final backendWallet = await _api.create(
          publicAddress: publicAddress,
          label: name ?? 'Wallet ${DateTime.now().millisecondsSinceEpoch}',
          network: 'stellar',
        );
        backendId = backendWallet.id;
      } catch (e) {
        debugPrint('[WalletManager] Backend creation failed: $e');

        try {
          final backendWallets = await _listBackendWallets(
            q: publicAddress,
            network: 'stellar',
          );
          final existing = backendWallets.firstWhereOrNull(
            (w) => w.publicAddress == publicAddress,
          );

          if (existing != null) {
            backendId = existing.id;
            reconnected = true;
            debugPrint(
              '[WalletManager] Reconnected to existing backend wallet: ${existing.label}',
            );

            if (name != null && name != existing.label) {
              try {
                await _api.updateLabel(walletId: existing.id, label: name);
              } catch (_) {}
            }
          }
        } catch (listError) {
          debugPrint(
            '[WalletManager] Failed to check existing wallets: $listError',
          );
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

  Future<WalletCreationResult> importWallet({
    required String mnemonic,
    required String publicAddress,
    String? name,
    bool makeActive = true,
  }) async {
    return createWallet(
      mnemonic: mnemonic,
      publicAddress: publicAddress,
      name: name,
      makeActive: makeActive,
    );
  }

  Future<List<WalletViewModel>> listWallets() async {
    final localWallets = await SeedStorage.listWallets();

    List<WalletAddress>? backendWallets;
    try {
      backendWallets = await _listBackendWallets();
    } catch (e) {
      debugPrint('[WalletManager] Backend fetch failed: $e');
    }

    final activeId = await SeedStorage.getActiveWalletId();

    return localWallets.map((local) {
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

  Future<bool> renameWallet({
    required String localId,
    required String newName,
  }) async {
    try {
      final localSuccess = await SeedStorage.renameWallet(localId, newName);
      if (!localSuccess) return false;

      final meta = await SeedStorage.getActiveWalletMeta();
      if (meta?.publicAddress == null) return localSuccess;

      try {
        final backendWallets = await _listBackendWallets();
        final backendWallet = backendWallets.firstWhereOrNull(
          (w) => w.publicAddress == meta!.publicAddress,
        );

        if (backendWallet != null) {
          await _api.updateLabel(walletId: backendWallet.id, label: newName);
        }
      } catch (e) {
        debugPrint('[WalletManager] Backend update failed: $e');
      }

      return true;
    } catch (e) {
      throw WalletException('Failed to rename wallet: $e');
    }
  }

  Future<bool> deleteWallet({required String localId}) async {
    try {
      final wallets = await listWallets();
      final wallet = wallets.firstWhereOrNull((w) => w.localId == localId);

      if (wallet == null) {
        throw WalletException('Wallet not found');
      }

      if (wallet.backendId != null) {
        try {
          await _api.remove(walletId: wallet.backendId!);
        } catch (e) {
          debugPrint('[WalletManager] Backend deletion failed: $e');
        }
      }

      final success = await SeedStorage.removeWallet(localId);
      return success;
    } catch (e) {
      throw WalletException('Failed to delete wallet: $e');
    }
  }

  Future<bool> switchWallet({required String localId}) async {
    final localSuccess = await SeedStorage.setActiveWallet(localId);
    if (!localSuccess) return false;

    try {
      final wallets = await listWallets();
      final wallet = wallets.firstWhereOrNull((w) => w.localId == localId);
      if (wallet?.backendId != null) {
        await _api.setActive(walletId: wallet!.backendId!);
      } else {
        await ensureLocalWalletSaved(
          localId: localId,
          setActiveIfCurrent: true,
        );
      }
    } catch (e) {
      debugPrint('[WalletManager] Backend setActive failed: $e');
    }

    return true;
  }

  Future<WalletViewModel?> getActiveWallet() async {
    final wallets = await listWallets();
    return wallets.firstWhereOrNull((w) => w.isActive);
  }

  Future<WalletAddress?> ensureLocalWalletSaved({
    String? localId,
    bool setActiveIfCurrent = true,
    String network = 'stellar',
  }) async {
    final localWallets = await SeedStorage.listWallets();
    final localMeta = (localId == null || localId.trim().isEmpty)
        ? await SeedStorage.getActiveWalletMeta()
        : localWallets.firstWhereOrNull((w) => w.id == localId);

    final publicAddress = localMeta?.publicAddress?.trim();
    if (localMeta == null || publicAddress == null || publicAddress.isEmpty) {
      return null;
    }

    final backendWallet = await saveAddressIfMissing(
      publicAddress: publicAddress,
      label: localMeta.name,
      network: network,
    );

    if (setActiveIfCurrent) {
      final activeId = await SeedStorage.getActiveWalletId();
      if (activeId == localMeta.id) {
        try {
          await _api.setActive(walletId: backendWallet.id);
        } catch (e) {
          debugPrint('[WalletManager] Backend setActive failed after save: $e');
        }
      }
    }

    return backendWallet;
  }

  Future<String?> getActiveWalletAddress() async {
    final active = await getActiveWallet();
    return active?.publicAddress;
  }

  Future<String?> getActiveWalletBackendId() async {
    final active = await getActiveWallet();
    return active?.backendId;
  }

  Future<SyncResult> syncToBackend() async {
    int created = 0;
    int updated = 0;
    int failed = 0;

    try {
      final localWallets = await SeedStorage.listWallets();
      final backendWallets = await _listBackendWallets();

      for (final local in localWallets) {
        if (local.publicAddress == null) continue;

        final exists = backendWallets.any(
          (b) => b.publicAddress == local.publicAddress,
        );

        if (!exists) {
          try {
            await _api.create(
              publicAddress: local.publicAddress!,
              label: local.name,
              network: 'stellar',
            );
            created++;
          } catch (e) {
            debugPrint('[WalletManager] Sync failed for ${local.name}: $e');
            failed++;
          }
        } else {
          final backend = backendWallets.firstWhere(
            (b) => b.publicAddress == local.publicAddress,
          );

          if (backend.label != local.name) {
            try {
              await _api.updateLabel(walletId: backend.id, label: local.name);
              updated++;
            } catch (e) {
              debugPrint('[WalletManager] Update failed for ${local.name}: $e');
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

  Future<List<CloudWallet>> pullFromBackend() async {
    try {
      final backendWallets = await _listBackendWallets();
      final localWallets = await SeedStorage.listWallets();

      final cloudOnlyWallets = <CloudWallet>[];

      for (final backend in backendWallets) {
        final exists = localWallets.any(
          (l) => l.publicAddress == backend.publicAddress,
        );

        if (!exists) {
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

  Future<WalletOverview> getWalletOverview({bool autoSync = true}) async {
    try {
      if (autoSync) {
        await _autoSyncLocalWallets();
      }

      final localWallets = await listWallets();

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

  Future<void> _autoSyncLocalWallets() async {
    try {
      final localWallets = await SeedStorage.listWallets();

      List<WalletAddress> backendWallets = [];
      try {
        backendWallets = await _listBackendWallets();
      } catch (e) {
        debugPrint('[WalletManager] Backend list failed during auto-sync: $e');
        return;
      }

      for (final local in localWallets) {
        if (local.publicAddress == null) continue;

        final exists = backendWallets.any(
          (b) => b.publicAddress == local.publicAddress,
        );

        if (!exists) {
          try {
            await _api.create(
              publicAddress: local.publicAddress!,
              label: local.name,
              network: 'stellar',
            );
            debugPrint('[WalletManager] Auto-synced wallet: ${local.name}');
          } catch (e) {
            debugPrint(
              '[WalletManager] Auto-sync failed for ${local.name}: $e',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[WalletManager] Auto-sync error: $e');
    }
  }

  Future<bool> hasLocalSeed(String publicAddress) async {
    final localWallets = await SeedStorage.listWallets();
    return localWallets.any((w) => w.publicAddress == publicAddress);
  }

  Future<bool> hasAddressInBackend(
    String publicAddress, {
    String network = 'stellar',
  }) async {
    final normalized = publicAddress.trim();
    if (normalized.isEmpty) return false;

    final backendWallets = await _listBackendWallets(
      q: normalized,
      network: network,
    );

    return backendWallets.any(
      (w) => w.publicAddress.trim().toLowerCase() == normalized.toLowerCase(),
    );
  }

  Future<WalletAddress> saveAddressIfMissing({
    required String publicAddress,
    String? label,
    String network = 'stellar',
  }) async {
    final normalized = publicAddress.trim();
    if (normalized.isEmpty) {
      throw WalletException('Public address is empty');
    }

    final existingList = await _listBackendWallets(
      q: normalized,
      network: network,
    );
    final existing = existingList.firstWhereOrNull(
      (w) => w.publicAddress.trim().toLowerCase() == normalized.toLowerCase(),
    );
    if (existing != null) return existing;

    try {
      return await _api.create(
        publicAddress: normalized,
        label: (label == null || label.trim().isEmpty)
            ? 'Wallet'
            : label.trim(),
        network: network,
      );
    } catch (_) {
      final retryList = await _listBackendWallets(
        q: normalized,
        network: network,
      );
      final retryExisting = retryList.firstWhereOrNull(
        (w) => w.publicAddress.trim().toLowerCase() == normalized.toLowerCase(),
      );
      if (retryExisting != null) return retryExisting;
      rethrow;
    }
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class WalletCreationResult {
  final String localId;
  final String? backendId;
  final String publicAddress;
  final bool syncedToBackend;
  final bool reconnected;

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

class WalletOverview {
  final List<WalletViewModel> localWallets;
  final List<CloudWallet> cloudOnlyWallets;
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
