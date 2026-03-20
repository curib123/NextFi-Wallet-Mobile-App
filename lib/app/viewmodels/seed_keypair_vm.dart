import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'dart:async';

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
  StreamSubscription<WalletStorageEvent>? _storageSub;
  int _loadEpoch = 0;

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
      _storageSub ??= SeedStorage.changes.listen((_) {
        unawaited(refresh());
      });
      await _loadFromStorage(markLoading: false);
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
      await _loadFromStorage(markLoading: false, preserveAccountId: true);
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

      _lastSyncedAt = null;
      await _loadFromStorage(markLoading: false);
      return true;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  Future<void> _loadFromStorage({
    required bool markLoading,
    bool preserveAccountId = false,
  }) async {
    final epoch = ++_loadEpoch;
    await SeedStorage.migrateLegacyIfNeeded();
    await SeedStorage.ensureActiveExists();

    final activeId = await SeedStorage.getActiveWalletId();
    final meta = await SeedStorage.getActiveWalletMeta();
    var accountId = meta?.publicAddress;

    if (accountId == null && (!preserveAccountId || _accountId == null)) {
      accountId = await _derivePublicAddress(activeId);
    } else if (accountId == null && preserveAccountId) {
      accountId = _accountId;
    }

    if (epoch != _loadEpoch) return;

    _activeId = activeId;
    _meta = meta;
    _accountId = accountId;
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

  Future<String?> _derivePublicAddress(String? walletId) async {
    final mnemonic = await SeedStorage.getActiveSeed();
    if (mnemonic == null || mnemonic.trim().isEmpty) return null;

    final pub = await StellarDerivation.deriveAccountId(
      mnemonic,
      index: _index,
    );

    final id = walletId;
    if (id != null) {
      await SeedStorage.setWalletPublicAddress(id, pub);
      _meta = await SeedStorage.getActiveWalletMeta();
    }
    return pub;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _storageSub?.cancel();
    super.dispose();
  }
}
