import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/Model/wallet_meta_model.dart';

/// Single-wallet secure storage for seed phrases.
/// - The FIRST wallet created/imported becomes the **Primary** and stays ACTIVE.
/// - Any subsequent “add/import” will keep **exactly one** wallet and make it ACTIVE.
/// - We prune to **one** wallet entry after every mutating operation.
class SeedStorage {
  // ---- Keys (versioned) ----
  static const _kIndexKey   = 'nextfi.wallets.index.v1';
  static const _kActiveKey  = 'nextfi.wallets.active.v1';
  static const _kLegacySeed = 'nextfi.seed.mnemonic.v1';

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
      return List<String>.from(jsonDecode(raw) as List);
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

  /// Ensure **exactly one** wallet exists; keep [keepId] (or active, or first).
  static Future<void> _pruneToSingle({String? keepId}) async {
    var ids = await _readIndex();
    if (ids.isEmpty && keepId == null) return;

    final active = await _storage.read(key: _kActiveKey);
    final primary = keepId ?? active ?? (ids.isNotEmpty ? ids.first : null);
    if (primary == null) return;

    for (final id in List<String>.from(ids)) {
      if (id == primary) continue;
      await _storage.delete(key: _seedKey(id));
      await _storage.delete(key: _metaKey(id));
      ids.remove(id);
    }

    ids = [primary];
    await _writeIndex(ids);
    await _setActive(primary); // ← always ensure ACTIVE after pruning
  }

  /// If active is missing but we have an index, set it active.
  static Future<void> ensureActiveExists() async {
    final active = await _storage.read(key: _kActiveKey);
    final ids = await _readIndex();
    if ((active == null || active.isEmpty) && ids.isNotEmpty) {
      await _setActive(ids.first);
      await _pruneToSingle(keepId: ids.first);
    }
  }

  // ---- Migration from legacy single-seed key ----
  static Future<void> migrateLegacyIfNeeded() async {
    final legacy = await _storage.read(key: _kLegacySeed);
    if (legacy == null || legacy.trim().isEmpty) return;

    final hasAny = (await _readIndex()).isNotEmpty;
    if (hasAny) {
      await _storage.delete(key: _kLegacySeed);
      await _pruneToSingle();
      return;
    }

    // Import legacy as Primary and make ACTIVE
    await addWallet(legacy.trim(), name: 'Imported Wallet'); // addWallet sets ACTIVE
    await _storage.delete(key: _kLegacySeed);
  }

  // ---- Core single-wallet API ----

  static Future<String> addWallet(String mnemonic, {String? name, String? publicAddress}) async {
    final value = mnemonic.trim();
    if (value.isEmpty) {
      throw ArgumentError('Mnemonic is empty.');
    }

    final index = await _readIndex();

    if (index.isEmpty) {
      // First (Primary) wallet → becomes ACTIVE
      final id = _makeId();
      final meta = WalletMetaModel(
        id: id,
        name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Primary Wallet',
        createdAt: _nowIso(),
        lastUsedAt: null,
        publicAddress: publicAddress,
      );

      await _writeIndex([id]);
      await _storage.write(key: _seedKey(id), value: value);
      await _writeMeta(meta);
      await _setActive(id);                  // ← ensure ACTIVE
      await _pruneToSingle(keepId: id);
      return id;
    }

    // Replace existing ACTIVE wallet's seed (no new id), then ensure ACTIVE
    final activeId = await getActiveWalletId() ?? index.first;
    await _storage.write(key: _seedKey(activeId), value: value);

    // Update meta if provided
    final meta = await _readMeta(activeId);
    if (meta != null) {
      if (name != null && name.trim().isNotEmpty) meta.name = name.trim();
      if (publicAddress != null) {
        meta.publicAddress = publicAddress.trim().isEmpty ? null : publicAddress.trim();
      }
      await _writeMeta(meta);
    }

    await _setActive(activeId);              // ← ensure ACTIVE on import/replace
    await _pruneToSingle(keepId: activeId);
    return activeId;
  }

  static Future<bool> updateSeed(String id, String mnemonic) async {
    final value = mnemonic.trim();
    if (value.isEmpty) return false;
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;

    await _storage.write(key: _seedKey(id), value: value);
    final back = await _storage.read(key: _seedKey(id));

    await _setActive(id);                    // ← NEW: make updated wallet ACTIVE
    await _pruneToSingle(keepId: id);
    return back == value;
  }

  static Future<bool> renameWallet(String id, String newName) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    final nm = newName.trim();
    if (nm.isEmpty || nm.length > 32) return false;
    meta.name = nm;
    await _writeMeta(meta);
    await _setActive(id);                    // ← keep ACTIVE invariant
    await _pruneToSingle(keepId: id);
    return true;
  }

  static Future<bool> setWalletPublicAddress(String id, String address) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    meta.publicAddress = address.trim().isEmpty ? null : address.trim();
    await _writeMeta(meta);
    await _setActive(id);                    // ← keep ACTIVE invariant
    await _pruneToSingle(keepId: id);
    return true;
  }

  static Future<bool> removeWallet(String id) async {
    final index = await _readIndex();
    if (!index.remove(id)) return false;

    await _writeIndex(index);
    await _storage.delete(key: _seedKey(id));
    await _storage.delete(key: _metaKey(id));

    // If we removed the active wallet, clear or set a remaining one active
    final active = await _storage.read(key: _kActiveKey);
    if (active == id) {
      if (index.isNotEmpty) {
        await _setActive(index.first);
      } else {
        await _storage.delete(key: _kActiveKey);
      }
    }

    await _pruneToSingle(keepId: await getActiveWalletId());
    return true;
  }

  static Future<List<WalletMetaModel>> listWallets() async {
    final ids = await _readIndex();
    final metas = <WalletMetaModel>[];
    for (final id in ids) {
      final m = await _readMeta(id);
      if (m != null) metas.add(m);
    }
    return metas;
  }

  static Future<String?> readSeed(String id) async {
    return await _storage.read(key: _seedKey(id));
  }

  static Future<String?> getActiveWalletId() async {
    return await _storage.read(key: _kActiveKey);
  }

  /// In single-wallet mode, this also prunes to one, keeping [id] ACTIVE.
  static Future<bool> setActiveWallet(String id) async {
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;
    await _setActive(id);
    await _pruneToSingle(keepId: id);
    return true;
  }

  static Future<WalletMetaModel?> getActiveWalletMeta() async {
    await ensureActiveExists();
    final id = await getActiveWalletId();
    if (id == null) return null;
    return _readMeta(id);
  }

  static Future<String?> getActiveSeed() async {
    await ensureActiveExists();
    final id = await getActiveWalletId();
    if (id == null) return null;
    return await _storage.read(key: _seedKey(id));
  }

  // ---- Backward-compat API (maps to ACTIVE wallet) ----

  static Future<bool> saveSeed(String mnemonic) async {
    final activeId = await getActiveWalletId();
    if (activeId == null) {
      final id = await addWallet(mnemonic, name: 'Primary Wallet'); // sets ACTIVE
      final saved = await readSeed(id);
      return saved == mnemonic.trim();
    } else {
      final ok = await updateSeed(activeId, mnemonic);              // sets ACTIVE
      await _pruneToSingle(keepId: activeId);
      return ok;
    }
  }

  static Future<String?> getSeed() async {
    return await getActiveSeed();
  }

  static Future<void> clearSeed() async {
    final id = await getActiveWalletId();
    if (id == null) return;
    await removeWallet(id);
  }
}
