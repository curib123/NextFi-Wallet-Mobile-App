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

  void _set(SeedPhraseState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Word count
  // ──────────────────────────────────────────────────────────────────────────

  /// Current target word count (12 or 24). Defaults to 12.
  int _wordCount = 12;
  int get wordCount => _wordCount;
  bool get isTwentyFour => _wordCount == 24;

  /// Switch word count and optionally regenerate immediately.
  Future<void> setWordCount(int count, {bool regenerateNow = false}) async {
    if (count != 12 && count != 24) return;
    if (_wordCount == count && !regenerateNow) return;
    _wordCount = count;
    if (regenerateNow) await regenerate();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Init / Regenerate
  // ──────────────────────────────────────────────────────────────────────────

  /// Initialize with a fresh mnemonic if one hasn't been generated yet.
  Future<void> init() async {
    if (_state.mnemonic.isNotEmpty) return;
    await regenerate();
  }

  /// Generate a new mnemonic (12 or 24 words) using [StellarWalletServices].
  ///
  /// [wordCountOverride] lets callers request a specific length without
  /// permanently changing [wordCount] on failure.
  Future<void> regenerate({int? wordCountOverride}) async {
    final count = (wordCountOverride == 12 || wordCountOverride == 24)
        ? wordCountOverride!
        : _wordCount;

    try {
      _set(_state.copyWith(loading: true, error: ''));

      final m = count == 24
          ? await _svc.generateMnemonic24()
          : await _svc.generateMnemonic12();

      final trimmed = m.trim();
      final words = trimmed.split(RegExp(r'\s+'));

      _set(_state.copyWith(
        loading: false,
        mnemonic: trimmed,
        words: words,
        obscured: true,
        ack1: false,
        ack2: false,
      ));
      _wordCount = count;
    } catch (e) {
      _set(_state.copyWith(
        loading: false,
        error: 'Failed to generate phrase: $e',
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI toggles
  // ──────────────────────────────────────────────────────────────────────────

  void toggleObscure() =>
      _set(_state.copyWith(obscured: !_state.obscured, error: ''));

  void forceHide() {
    if (!_state.obscured) _set(_state.copyWith(obscured: true));
  }

  void setAck1(bool v) => _set(_state.copyWith(ack1: v));
  void setAck2(bool v) => _set(_state.copyWith(ack2: v));

  // ──────────────────────────────────────────────────────────────────────────
  // Validation / readiness
  // ──────────────────────────────────────────────────────────────────────────

  /// Normalize whitespace and case for storage / comparison.
  String normalized() =>
      _state.mnemonic.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get readyToSecure =>
      !_state.obscured && _state.ack1 && _state.ack2 && !_state.loading;

  // ──────────────────────────────────────────────────────────────────────────
  // Save
  // ──────────────────────────────────────────────────────────────────────────

  /// Save the current phrase securely:
  ///   1. Validates via [StellarWalletServices.validateMnemonic] (async).
  ///   2. Adds a **new wallet** entry and makes it **active**
  ///      (preserves existing wallets).
  ///   3. Verifies persistence by reading back the active seed.
  Future<bool> saveSecurely() async {
    final phrase = normalized();

    // Validate (async in SDK v3).
    final valid = await _svc.validateMnemonic(phrase);
    if (!valid) {
      _set(_state.copyWith(
        error: 'Please enter a valid 12- or 24-word recovery phrase.',
      ));
      return false;
    }

    try {
      _set(_state.copyWith(loading: true, error: ''));

      // Add as a new wallet and make it active (does NOT overwrite existing).
      await SeedStorage.addWallet(
        phrase,
        makeActive: true,
      );

      // Verify by reading back the active seed.
      final stored = await SeedStorage.getActiveSeed();
      if (stored == null || stored.trim().isEmpty) {
        _set(_state.copyWith(
          loading: false,
          error: 'Could not verify saved phrase. Please try again.',
        ));
        return false;
      }

      // Strict equality check (normalized).
      final storedNorm =
      stored.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (storedNorm != phrase) {
        _set(_state.copyWith(
          loading: false,
          error: 'Saved phrase mismatch. Please try again.',
        ));
        return false;
      }

      _set(_state.copyWith(loading: false));
      return true;
    } catch (e) {
      _set(_state.copyWith(loading: false, error: 'Unexpected error: $e'));
      return false;
    }
  }
}