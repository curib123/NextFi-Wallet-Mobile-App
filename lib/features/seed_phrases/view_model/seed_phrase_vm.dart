// lib/features/seed_phrase/viewmodel/seed_phrase_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import '../model/seed_phrase_state.dart';

class SeedPhraseVM extends ChangeNotifier {
  SeedPhraseState _state = const SeedPhraseState();
  SeedPhraseState get state => _state;

  void _set(SeedPhraseState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> init() async {
    if (_state.mnemonic.isNotEmpty) return;
    await regenerate();
  }

  Future<void> regenerate() async {
    try {
      _set(_state.copyWith(loading: true, error: ''));
      final m = await StellarWalletService.generateMnemonic();
      final w = m.trim().split(RegExp(r'\s+'));
      _set(_state.copyWith(
        loading: false,
        mnemonic: m.trim(),
        words: w,
        obscured: true,
        ack1: false,
        ack2: false,
      ));
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to generate phrase: $e'));
    }
  }

  void toggleObscure() => _set(_state.copyWith(obscured: !_state.obscured, error: ''));

  void setAck1(bool v) => _set(_state.copyWith(ack1: v));
  void setAck2(bool v) => _set(_state.copyWith(ack2: v));

  String normalized() =>
      _state.mnemonic.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get readyToSecure => !_state.obscured && _state.ack1 && _state.ack2 && !_state.loading;

  Future<bool> saveSecurely() async {
    final phrase = normalized();
    if (phrase.isEmpty || phrase.split(' ').length < 12) {
      _set(_state.copyWith(error: 'Please enter a valid 12/24-word recovery phrase.'));
      return false;
    }
    try {
      _set(_state.copyWith(loading: true, error: ''));
      final ok = await SeedStorage.saveSeed(phrase);
      if (!ok) {
        _set(_state.copyWith(loading: false, error: 'Failed to save your wallet. Please try again.'));
        return false;
      }
      final stored = await SeedStorage.getSeed();
      if (stored == null || stored.isEmpty) {
        _set(_state.copyWith(loading: false, error: 'Could not verify saved phrase. Please try again.'));
        return false;
      }
      _set(_state.copyWith(loading: false));
      return true;
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Unexpected error: $e'));
      return false;
    }
  }

  void forceHide() { if (!_state.obscured) _set(_state.copyWith(obscured: true)); }
}
