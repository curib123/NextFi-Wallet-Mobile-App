// lib/reusable_view_model/seed_keypair_vm.dart
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/services/seed_storage.dart';
import 'package:next_fi/reusable_model/wallet_meta_model.dart';

/// Helper for deterministic derivation using the SDK's built-in SEP-0005 Wallet.
///
/// Uses `stellar_flutter_sdk` v3's [Wallet] class which implements
/// BIP-39 mnemonic handling and SLIP-0010 / BIP-44 key derivation
/// (path: m/44'/148'/index') internally — no external `bip39` or
/// `ed25519_hd_key` packages required.
class StellarDerivation {
  /// Derive a Stellar [KeyPair] from a BIP-39 mnemonic.
  ///
  /// The SDK's [Wallet] class handles:
  ///   1. Mnemonic validation
  ///   2. BIP-39 seed generation (PBKDF2-HMAC-SHA512, 2048 iterations)
  ///   3. SLIP-0010 derivation on path m/44'/148'/[index]'
  ///
  /// [index] defaults to 0 (first Stellar account).
  static Future<KeyPair> deriveKeyPairFromMnemonic(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    final wallet = await Wallet.from(
      mnemonic.trim(),
      passphrase: passphrase,
    );
    return wallet.getKeyPair(index: index);
  }

  /// Convenience: derive only the public account ID (G…).
  static Future<String> deriveAccountId(
      String mnemonic, {
        int index = 0,
        String passphrase = '',
      }) async {
    final wallet = await Wallet.from(
      mnemonic.trim(),
      passphrase: passphrase,
    );
    return wallet.getAccountId(index: index);
  }

  /// Validate a mnemonic phrase using the SDK's built-in validator.
  static Future<bool> validateMnemonic(String mnemonic) async {
    return Wallet.validate(mnemonic.trim());
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

  // Derivation index (Stellar BIP-44 account index, default 0).
  int _index = 0;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;

  String? get activeWalletId => _activeId;
  WalletMetaModel? get meta => _meta;

  /// Public address (G…)
  String? get accountId => _accountId;

  int get index => _index;

  set index(int v) {
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
        await _deriveAndCachePublicAddress();
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
        await _deriveAndCachePublicAddress();
      }
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  /// Switch ACTIVE wallet (no pruning — aligns with SeedStorage semantics).
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

      if (_accountId == null) {
        await _deriveAndCachePublicAddress();
      }
      return true;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  /// Ephemerally derive the KeyPair from the ACTIVE wallet's mnemonic.
  /// Does NOT keep the mnemonic or private key in member fields.
  Future<KeyPair> deriveKeyPair({String passphrase = ''}) async {
    final mnemonic = await SeedStorage.getActiveSeed();
    if (mnemonic == null || mnemonic.trim().isEmpty) {
      throw StateError('No active wallet seed found.');
    }
    final kp = await StellarDerivation.deriveKeyPairFromMnemonic(
      mnemonic,
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

  // ----- private helpers -----

  /// Derives the public address from the active seed, caches it, and
  /// persists to SeedStorage (best-effort).
  Future<void> _deriveAndCachePublicAddress() async {
    final mnemonic = await SeedStorage.getActiveSeed();
    if (mnemonic == null || mnemonic.trim().isEmpty) return;

    final pub = await StellarDerivation.deriveAccountId(
      mnemonic,
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