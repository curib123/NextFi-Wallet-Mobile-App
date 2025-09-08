import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/Model/wallet_meta_model.dart';



/// Multi-wallet secure storage for seed phrases.
class SeedStorage {
  // ---- Keys (versioned) ----
  static const _kIndexKey   = 'nextfi.wallets.index.v1';  // JSON: ["w_...","w_..."]
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

  // ---- Migration from legacy single-seed key ----
  static Future<void> migrateLegacyIfNeeded() async {
    final legacy = await _storage.read(key: _kLegacySeed);
    if (legacy == null || legacy.trim().isEmpty) return;

    final haveAny = (await _readIndex()).isNotEmpty;
    if (haveAny) {
      await _storage.delete(key: _kLegacySeed);
      return;
    }

    await addWallet(legacy.trim(), name: 'Imported Wallet');
    await _storage.delete(key: _kLegacySeed);
  }

  // ---- Core multi-wallet API ----

  /// Create/add new wallet. Returns wallet id.
  static Future<String> addWallet(String mnemonic, {String? name, String? publicAddress}) async {
    final value = mnemonic.trim();
    if (value.isEmpty) {
      throw ArgumentError('Mnemonic is empty.');
    }

    final id = _makeId();
    final meta = WalletMetaModel(
      id: id,
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Wallet',
      createdAt: _nowIso(),
      lastUsedAt: null,
      publicAddress: publicAddress,
    );

    final index = await _readIndex();
    index.insert(0, id); // newest first
    await _writeIndex(index);

    await _storage.write(key: _seedKey(id), value: value);
    await _writeMeta(meta);

    final active = await _storage.read(key: _kActiveKey);
    if (active == null) {
      await _setActive(id);
    }
    return id;
  }

  static Future<bool> updateSeed(String id, String mnemonic) async {
    final value = mnemonic.trim();
    if (value.isEmpty) return false;
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;
    await _storage.write(key: _seedKey(id), value: value);
    final back = await _storage.read(key: _seedKey(id));
    return back == value;
  }

  static Future<bool> renameWallet(String id, String newName) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    final nm = newName.trim();
    if (nm.isEmpty || nm.length > 32) return false;
    meta.name = nm;
    await _writeMeta(meta);
    return true;
  }

  static Future<bool> setWalletPublicAddress(String id, String address) async {
    final meta = await _readMeta(id);
    if (meta == null) return false;
    meta.publicAddress = address.trim().isEmpty ? null : address.trim();
    await _writeMeta(meta);
    return true;
  }

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

  static Future<bool> setActiveWallet(String id) async {
    final exists = (await _readIndex()).contains(id);
    if (!exists) return false;
    await _setActive(id);
    return true;
  }

  static Future<WalletMetaModel?> getActiveWalletMeta() async {
    final id = await getActiveWalletId();
    if (id == null) return null;
    return _readMeta(id);
  }

  static Future<String?> getActiveSeed() async {
    final id = await getActiveWalletId();
    if (id == null) return null;
    return await _storage.read(key: _seedKey(id));
  }

  // ---- Backward-compat API (maps to ACTIVE wallet) ----

  static Future<bool> saveSeed(String mnemonic) async {
    final activeId = await getActiveWalletId();
    if (activeId == null) {
      final id = await addWallet(mnemonic, name: 'Primary Wallet');
      return (await readSeed(id)) == mnemonic.trim();
    } else {
      return await updateSeed(activeId, mnemonic);
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
