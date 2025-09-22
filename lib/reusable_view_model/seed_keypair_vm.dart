// lib/reusable_view_model/seed_keypair_vm.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/seed_storage.dart';
import 'package:next_fi/reusable_model/wallet_meta_model.dart';

/// Helper for deterministic derivation (BIP-39 -> ed25519 using BIP-44 for Stellar).
class StellarDerivation {
  /// Derive a Stellar KeyPair from a BIP-39 mnemonic.
  ///
  /// Default path: m/44'/148'/0' (Stellar coin type 148; account 0).
  /// For multiple accounts/addresses, bump [account] and/or [index] (both hardened).
  static Future<KeyPair> deriveKeyPairFromMnemonic(
      String mnemonic, {
        int account = 0,
        int? index, // optional hardened child
        String passphrase = '',
      }) async {
    final m = mnemonic.trim();
    if (!bip39.validateMnemonic(m)) {
      throw ArgumentError('Invalid mnemonic.');
    }

    // 1) BIP-39 -> seed bytes
    final Uint8List seed = bip39.mnemonicToSeed(m, passphrase: passphrase);

    // 2) Derive ed25519 key via BIP-44: m/44'/148'/account'[/index']
    final segments = <String>["m", "44'", "148'", "$account'"];
    if (index != null) segments.add("$index'");
    final path = segments.join('/');

    final KeyData keyData = await ED25519_HD_KEY.derivePath(path, seed);
    final Uint8List sk = Uint8List.fromList(keyData.key); // 32-byte ed25519 secret seed

    // 3) Build KeyPair (SDK differences handled)
    try {
      // Available in newer stellar_flutter_sdk
      return KeyPair.fromSecretSeedList(sk);
    } catch (_) {
      // Fallback for older SDK: encode raw 32-byte seed to StrKey then import
      final String secret = StrKey.encodeStellarSecretSeed(sk);
      return KeyPair.fromSecretSeed(secret);
    }
  }

  /// Convenience: derive only the public account ID.
  static Future<String> deriveAccountId(
      String mnemonic, {
        int account = 0,
        int? index,
        String passphrase = '',
      }) async {
    final kp = await deriveKeyPairFromMnemonic(
      mnemonic,
      account: account,
      index: index,
      passphrase: passphrase,
    );
    return kp.accountId;
  }
}

/// Provider / ViewModel that exposes active wallet meta + public address
/// and can **ephemerally** derive a KeyPair from SeedStorage on demand.
class SeedKeypairVM extends ChangeNotifier {
  bool _isLoading = false;
  bool _isBusy = false;
  bool _disposed = false;

  String? _activeId;
  WalletMetaModel? _meta;
  String? _accountId; // cached public address for quick UI access
  DateTime? _lastSyncedAt;

  // Optional derivation parameters (default Stellar: account=0, no index)
  int _account = 0;
  int? _index;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;

  String? get activeWalletId => _activeId;
  WalletMetaModel? get meta => _meta;

  /// Public address (G...)
  String? get accountId => _accountId;

  int get account => _account;
  int? get index => _index;

  set account(int v) {
    if (_account != v) {
      _account = v;
      _accountId = null; // invalidate cache until rederived
      _safeNotify();
    }
  }

  set index(int? v) {
    if (_index != v) {
      _index = v;
      _accountId = null; // invalidate cache until rederived
      _safeNotify();
    }
  }

  Future<void> init() async {
    if (_isLoading) return;
    _isLoading = true;
    _safeNotify();
    try {
      await SeedStorage.migrateLegacyIfNeeded();
      await SeedStorage.ensureActiveExists();

      _activeId = await SeedStorage.getActiveWalletId();
      _meta = await SeedStorage.getActiveWalletMeta();
      _accountId = _meta?.publicAddress;

      // If we don't have a cached public address, derive once and persist.
      if (_accountId == null) {
        final mnemonic = await SeedStorage.getActiveSeed();
        if (mnemonic != null && mnemonic.trim().isNotEmpty) {
          final pub = await StellarDerivation.deriveAccountId(
            mnemonic,
            account: _account,
            index: _index,
          );
          _accountId = pub;
          _lastSyncedAt = DateTime.now();

          // Save to meta for faster future loads (best-effort).
          final id = _activeId;
          if (id != null) {
            await SeedStorage.setWalletPublicAddress(id, pub);
            _meta = await SeedStorage.getActiveWalletMeta(); // refresh meta cache
          }
        }
      }
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Refresh metadata and (if needed) re-derive the public address.
  Future<void> refresh() async {
    if (_isBusy) return;
    _isBusy = true;
    _safeNotify();
    try {
      _activeId = await SeedStorage.getActiveWalletId();
      _meta = await SeedStorage.getActiveWalletMeta();
      _accountId = _meta?.publicAddress ?? _accountId;

      if (_accountId == null) {
        final mnemonic = await SeedStorage.getActiveSeed();
        if (mnemonic != null && mnemonic.trim().isNotEmpty) {
          final pub = await StellarDerivation.deriveAccountId(
            mnemonic,
            account: _account,
            index: _index,
          );
          _accountId = pub;
          _lastSyncedAt = DateTime.now();

          final id = _activeId;
          if (id != null) {
            await SeedStorage.setWalletPublicAddress(id, pub);
            _meta = await SeedStorage.getActiveWalletMeta();
          }
        }
      }
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  /// Switch ACTIVE wallet (no pruning — aligns with your SeedStorage semantics).
  Future<bool> switchTo(String id) async {
    if (_isBusy) return false;
    _isBusy = true;
    _safeNotify();
    try {
      final ok = await SeedStorage.setActiveWallet(id);
      if (!ok) return false;

      _activeId = await SeedStorage.getActiveWalletId();
      _meta = await SeedStorage.getActiveWalletMeta();
      _accountId = _meta?.publicAddress;
      _lastSyncedAt = null;

      // Derive public if missing
      if (_accountId == null) {
        final mnemonic = await SeedStorage.getActiveSeed();
        if (mnemonic != null && mnemonic.trim().isNotEmpty) {
          _accountId = await StellarDerivation.deriveAccountId(
            mnemonic,
            account: _account,
            index: _index,
          );
          if (_activeId != null) {
            await SeedStorage.setWalletPublicAddress(_activeId!, _accountId!);
            _meta = await SeedStorage.getActiveWalletMeta();
          }
        }
      }
      return true;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  /// Ephemerally derive the KeyPair from the ACTIVE wallet’s mnemonic.
  /// Does NOT keep the mnemonic or private key in member fields.
  Future<KeyPair> deriveKeyPair({String passphrase = ''}) async {
    final mnemonic = await SeedStorage.getActiveSeed();
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      throw StateError('No active wallet seed found.');
    }
    final kp = await StellarDerivation.deriveKeyPairFromMnemonic(
      mnemonic,
      account: _account,
      index: _index,
      passphrase: passphrase,
    );

    // Update cached public address if missing or changed.
    if (_accountId != kp.accountId) {
      _accountId = kp.accountId;
      _lastSyncedAt = DateTime.now();
      if (_activeId != null) {
        await SeedStorage.setWalletPublicAddress(_activeId!, kp.accountId);
        _meta = await SeedStorage.getActiveWalletMeta();
      }
      _safeNotify();
    }
    return kp;
  }

  /// Optionally expose last sync time for UI.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  // ----- lifecycle & safe notify -----
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
