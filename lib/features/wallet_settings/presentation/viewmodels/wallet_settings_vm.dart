// lib/features/wallet_settings/viewmodel/wallet_settings_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/features/wallet_settings/presentation/viewmodels/wallet_settings_state.dart';

class WalletSettingsVM extends ChangeNotifier {
  WalletSettingsState _state = const WalletSettingsState();
  WalletSettingsState get state => _state;

  void _set(WalletSettingsState s) { _state = s; notifyListeners(); }

  Future<void> init() async {
    try {
      await SeedStorage.migrateLegacyIfNeeded();
      await _loadSecrets();
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to init: $e'));
    }
  }

  Future<void> _loadSecrets() async {
    try {
      final meta = await SeedStorage.getActiveWalletMeta();
      final seed = await SeedStorage.getSeed(); // active wallet seed
      if (seed == null || seed.trim().isEmpty) {
        _set(_state.copyWith(
          activeWalletId: meta?.id,
          walletName: meta?.name ?? "My Wallet",
          mnemonic: "",
          words: const [],
          loading: false,
          error: '',
        ));
        return;
      }
      final words = seed.trim().split(RegExp(r'\s+'));
      _set(_state.copyWith(
        activeWalletId: meta?.id,
        walletName: meta?.name ?? "My Wallet",
        mnemonic: seed.trim(),
        words: words,
        loading: false,
        error: '',
      ));
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to load wallet: $e'));
    }
  }

  Future<void> refresh() => _loadSecrets();

  void setAuthorized(bool v) => _set(_state.copyWith(authorized: v));

  void toggleObscure() => _set(_state.copyWith(obscured: !_state.obscured, error: ''));

  void forceHide() { if (!_state.obscured) _set(_state.copyWith(obscured: true)); }

  Future<bool> renameActive(String newName) async {
    final id = _state.activeWalletId;
    if (id == null) return false;
    final ok = await SeedStorage.renameWallet(id, newName);
    if (ok) _set(_state.copyWith(walletName: newName));
    return ok;
  }

  Future<bool> switchActive(String walletId) async {
    final ok = await SeedStorage.setActiveWallet(walletId);
    if (ok) await _loadSecrets();
    return ok;
  }
}
