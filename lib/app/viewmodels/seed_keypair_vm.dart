import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/models/wallet_meta_model.dart';

class StellarDerivation {
  static Future<KeyPair> deriveKeyPairFromMnemonic(
    String mnemonic, {
    int index = 0,
    String passphrase = '',
  }) async {
    final wallet = await Wallet.from(mnemonic.trim(), passphrase: passphrase);
    return wallet.getKeyPair(index: index);
  }

  static Future<String> deriveAccountId(
    String mnemonic, {
    int index = 0,
    String passphrase = '',
  }) async {
    final wallet = await Wallet.from(mnemonic.trim(), passphrase: passphrase);
    return wallet.getAccountId(index: index);
  }

  static Future<bool> validateMnemonic(String mnemonic) async {
    return Wallet.validate(mnemonic.trim());
  }
}

class SeedKeypairVM extends ChangeNotifier {
  bool _isLoading = false;
  bool _isBusy = false;
  bool _disposed = false;

  String? _activeId;
  WalletMetaModel? _meta;
  String? _accountId;
  DateTime? _lastSyncedAt;

  int _index = 0;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;

  String? get activeWalletId => _activeId;
  WalletMetaModel? get meta => _meta;

  String? get accountId => _accountId;

  int get index => _index;

  set index(int v) {
    if (_index != v) {
      _index = v;
      _accountId = null;
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

      if (_accountId == null) {
        await _deriveAndCachePublicAddress();
      }
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

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

  DateTime? get lastSyncedAt => _lastSyncedAt;

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

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
