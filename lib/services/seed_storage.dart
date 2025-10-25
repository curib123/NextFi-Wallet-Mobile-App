import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/reusable_model/wallet_meta_model.dart';

/// Multi-wallet secure storage for seed phrases (backward-compatible API).
/// Behavior highlights:
/// - FIRST wallet created/imported becomes **ACTIVE**.
/// - Subsequent `addWallet` calls create **new** wallets; by default they
///   also become **ACTIVE** without deleting the previous ones.
/// - No pruning; multiple wallets are preserved.
/// - Back-compat methods (`saveSeed`, `getSeed`, `clearSeed`) map to ACTIVE.
class SeedStorage {
  // ---- Keys (versioned) ----
  static const _kIndexKey   = 'nextfi.wallets.index.v1';  // JSON: ["w_..."] (newest-first recommended)
  static const _kActiveKey  = 'nextfi.wallets.active.v1'; // "w_..."
  static const _kLegacySeed = 'nextfi.seed.mnemonic.v1';  // old single-seed key

  static String _seedKey(String id) => 'nextfi.wallets.$id.seed';
  static String _metaKey(String id) => 'nextfi.wallets.$id.meta';

  // ---- Secure storage instance ----
  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ---- Id/Time helpers ----
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _makeId() {
    final r = Random.secure();
    final salt = List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    return 'w_${DateTime.now().millisecondsSinceEpoch}_$salt';
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // ---- Private helpers ----
  static Future<List<String>> _readIndex() async {
    final raw = await _storage.read(key: _kIndexKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final list = List<String>.from(jsonDecode(raw) as List);
      // De-dup just in case
      final seen = <String>{};
      final uniq = <String>[];
      for (final id in list) {
        if (seen.add(id)) uniq.add(id);
      }
      return uniq;
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> _writeIndex(List<String> ids) async {
    await _storage.write(key: _kIndexKey, value: jsonEncode(ids));
  }

  static Future<WalletMetaModel?> _readMeta(String id) async {
    final raw = await _storage.read(key: _metaKey(id));
    if (raw == null) return null;
    try {
      return WalletMetaModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeMeta(WalletMetaModel m) async {
    await _storage.write(key: _metaKey(m.id), value: jsonEncode(m.toJson()));
  }

  static Future<void> _setActive(String id) async {
    await _storage.write(key: _kActiveKey, value: id);
    final meta = await _readMeta(id);
    if (meta != null) {
      meta.lastUsedAt = _nowIso();
      await _writeMeta(meta);
    }
  }

  /// Ensure there is an ACTIVE wallet if any exist (no pruning).
  static Future<void> ensureActiveExists() async {
    final active = await _storage.read(key: _kActiveKey);
    final ids = await _readIndex();
    if ((active == null || active.isEmpty) && ids.isNotEmpty) {
      await _setActive(ids.first);
    }
  }

  // ---- Migration from legacy single-seed key ----
  static Future<void> migrateLegacyIfNeeded() async {
    final legacy = await _storage.read(key: _kLegacySeed);
    if (legacy == null || legacy.trim().isEmpty) return;

    final hasAny = (await _readIndex()).isNotEmpty;
    if (hasAny) {
      // If we already have wallets, just drop legacy.
      await _storage.delete(key: _kLegacySeed);
      return;
    }

    // Import legacy as first (ACTIVE) wallet.
    await addWallet(legacy.trim(), name: 'Imported Wallet', makeActive: true);
    await _storage.delete(key: _kLegacySeed);
  }

  // ---- Multi-wallet API (backward-compatible method names) ----

  /// Create a new wallet.
  /// - If it's the first one, it becomes ACTIVE.
  /// - If wallets already exist, you can choose to activate the new one via [makeActive] (default: true).
  static Future<String> addWallet(
      String mnemonic, {
        String? name,
        String? publicAddress,
        bool makeActive = true,
      }) async {
    final value = mnemonic.trim();
    if (value.isEmpty) {
      throw ArgumentError('Mnemonic is empty.');
    }

    final index = await _readIndex();

    // First wallet → create and activate (same behavior as before)
    if (index.isEmpty) {
      final id = _makeId();
      final meta = WalletMetaModel(
        id: id,
        name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Primary Wallet',
        createdAt: _nowIso(),
        lastUsedAt: null,
        publicAddress: publicAddress?.trim().isEmpty ?? true ? null : publicAddress!.trim(),
      );
      await _writeIndex([id]);
      await _storage.write(key: _seedKey(id), value: value);
      await _writeMeta(meta);
      await _setActive(id);
      return id;
    }

    // Additional wallet → create NEW id; optionally make it ACTIVE
    final id = _makeId();
    final meta = WalletMetaModel(
      id: id,
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Wallet ${index.length + 1}',
      createdAt: _nowIso(),
      lastUsedAt: null,
      publicAddress: publicAddress?.trim().isEmpty ?? true ? null : publicAddress!.trim(),
    );

    // Prepend new wallet id (newest-first)
    final next = [id, ...index];
    await _writeIndex(next);
    await _storage.write(key: _seedKey(id), value: value);
    await _writeMeta(meta);

    if (makeActive) {
      await _setActive(id);
    }
    return id;
  }

  /// Update the seed of an existing wallet. Keeps behavior of promoting it to ACTIVE.
  static Future<bool> updateSeed(String id, String mnemonic) async {
    final value = mnemonic.trim();
    if (value.isEmpty) return false;
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;

    await _storage.write(key: _seedKey(id), value: value);
    final back = await _storage.read(key: _seedKey(id));

    // Preserve previous "make updated wallet ACTIVE" behavior for compatibility
    await _setActive(id);
    return back == value;
  }

  /// Rename a wallet. Keeps prior behavior of making it ACTIVE for compatibility.
  static Future<bool> renameWallet(String id, String newName) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    final nm = newName.trim();
    if (nm.isEmpty || nm.length > 32) return false;
    meta.name = nm;
    await _writeMeta(meta);
    await _setActive(id);
    return true;
  }

  /// Set or clear a wallet's public address. Keeps prior behavior of making it ACTIVE.
  static Future<bool> setWalletPublicAddress(String id, String address) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    final trimmed = address.trim();
    meta.publicAddress = trimmed.isEmpty ? null : trimmed;
    await _writeMeta(meta);
    await _setActive(id);
    return true;
  }

  /// Remove a wallet. If it was ACTIVE, move ACTIVE to the next available or clear it.
  static Future<bool> removeWallet(String id) async {
    final index = await _readIndex();
    if (!index.remove(id)) return false;

    await _writeIndex(index);
    await _storage.delete(key: _seedKey(id));
    await _storage.delete(key: _metaKey(id));

    final active = await _storage.read(key: _kActiveKey);
    if (active == id) {
      if (index.isNotEmpty) {
        await _setActive(index.first);
      } else {
        await _storage.delete(key: _kActiveKey);
      }
    }
    return true;
  }

  /// List all wallet metadata (in index order; newest-first if you always prepend).
  static Future<List<WalletMetaModel>> listWallets() async {
    final ids = await _readIndex();
    final metas = <WalletMetaModel>[];
    for (final id in ids) {
      final m = await _readMeta(id);
      if (m != null) metas.add(m);
    }
    return metas;
  }

  /// Read the seed/mnemonic for a given wallet id.
  static Future<String?> readSeed(String id) async {
    return await _storage.read(key: _seedKey(id));
  }

  /// Get ACTIVE wallet id (may be null).
  static Future<String?> getActiveWalletId() async {
    return await _storage.read(key: _kActiveKey);
  }

  /// Set ACTIVE wallet (no pruning).
  static Future<bool> setActiveWallet(String id) async {
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;
    await _setActive(id);
    return true;
  }

  /// Get ACTIVE wallet metadata (or null).
  static Future<WalletMetaModel?> getActiveWalletMeta() async {
    await ensureActiveExists();
    final id = await getActiveWalletId();
    if (id == null) return null;
    return _readMeta(id);
  }

  /// Get ACTIVE wallet seed (or null).
  static Future<String?> getActiveSeed() async {
    await ensureActiveExists();
    final id = await getActiveWalletId();
    if (id == null) return null;
    return await _storage.read(key: _seedKey(id));
  }

  // ---- Backward-compat API (maps to ACTIVE wallet) ----

  /// If no ACTIVE wallet exists, creates the first one and sets it ACTIVE.
  /// Otherwise, updates the ACTIVE wallet's seed (legacy "replace current" behavior).
  static Future<bool> saveSeed(String mnemonic) async {
    final activeId = await getActiveWalletId();
    if (activeId == null) {
      final id = await addWallet(mnemonic, name: 'Primary Wallet', makeActive: true); // sets ACTIVE
      final saved = await readSeed(id);
      return saved == mnemonic.trim();
    } else {
      final ok = await updateSeed(activeId, mnemonic); // sets ACTIVE
      return ok;
    }
  }

  /// Legacy "get current seed" (ACTIVE).
  static Future<String?> getSeed() async {
    return await getActiveSeed();
  }

  /// Legacy "clear current seed" (removes ACTIVE wallet entry).
  static Future<void> clearSeed() async {
    final id = await getActiveWalletId();
    if (id == null) return;
    await removeWallet(id);
  }
}
