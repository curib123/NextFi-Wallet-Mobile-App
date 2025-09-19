// lib/features/seed_phrase/viewmodel/seed_phrase_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/seed_phrases/model/seed_phrase_state.dart';
import 'package:next_fi/services/seed_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';

class SeedPhraseVM extends ChangeNotifier {
  SeedPhraseVM({required StellarWalletServices service}) : _svc = service;

  final StellarWalletServices _svc;

  SeedPhraseState _state = const SeedPhraseState();
  SeedPhraseState get state => _state;

  bool _disposed = false;
  void _set(SeedPhraseState s) { _state = s; if (!_disposed) notifyListeners(); }
  @override void dispose() { _disposed = true; super.dispose(); }

  /// Current target word count. Defaults to 12.
  int _wordCount = 12;
  int get wordCount => _wordCount;
  bool get isTwentyFour => _wordCount == 24;

  /// Switch word count to 12 or 24 and (optionally) regenerate immediately.
  Future<void> setWordCount(int count, {bool regenerateNow = false}) async {
    if (count != 12 && count != 24) return;
    if (_wordCount == count) return;
    _wordCount = count;
    if (regenerateNow) await regenerate();
  }

  Future<void> init() async {
    if (_state.mnemonic.isNotEmpty) return;
    await regenerate();
  }

  /// Quick helpers using the service getters.
  Future<void> regenerate12() => _regenerateViaGetter(12);
  Future<void> regenerate24() => _regenerateViaGetter(24);

  Future<void> _regenerateViaGetter(int wc) async {
    try {
      _set(_state.copyWith(loading: true, error: ''));
      final m = wc == 24 ? await _svc.mnemonic24 : await _svc.mnemonic12;
      final w = m.trim().split(RegExp(r'\s+'));
      _set(_state.copyWith(
        loading: false,
        mnemonic: m.trim(),
        words: w,
        obscured: true,
        ack1: false,
        ack2: false,
      ));
      _wordCount = wc;
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to generate phrase: $e'));
    }
  }

  /// Generate a new phrase using StellarWalletServices (12 or 24 words).
  Future<void> regenerate({int? wordCountOverride}) async {
    final count = (wordCountOverride == 12 || wordCountOverride == 24)
        ? wordCountOverride!
        : _wordCount;

    try {
      _set(_state.copyWith(loading: true, error: ''));
      // Prefer the new getters; equivalent to generateMnemonic(wordCount: count)
      final m = count == 24 ? await _svc.mnemonic24 : await _svc.mnemonic12;

      final w = m.trim().split(RegExp(r'\s+'));
      _set(_state.copyWith(
        loading: false,
        mnemonic: m.trim(),
        words: w,
        obscured: true,
        ack1: false,
        ack2: false,
      ));
      _wordCount = count; // persist chosen count
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Failed to generate phrase: $e'));
    }
  }

  void toggleObscure() =>
      _set(_state.copyWith(obscured: !_state.obscured, error: ''));

  void setAck1(bool v) => _set(_state.copyWith(ack1: v));
  void setAck2(bool v) => _set(_state.copyWith(ack2: v));

  String normalized() =>
      _state.mnemonic.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get readyToSecure =>
      !_state.obscured && _state.ack1 && _state.ack2 && !_state.loading;

  Future<bool> saveSecurely() async {
    final phrase = normalized();

    // Use the service validator (includes 12/24 check + checksum)
    if (!_svc.validateMnemonic(phrase)) {
      _set(_state.copyWith(error: 'Please enter a valid 12- or 24-word recovery phrase.'));
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

  void forceHide() {
    if (!_state.obscured) _set(_state.copyWith(obscured: true));
  }
}
