// lib/features/seed_phrase/viewmodel/seed_phrase_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/seed_phrases/model/seed_phrase_state.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';

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

  /// Current target word count (12, 18, or 24). Defaults to 12.
  int _wordCount = 12;
  int get wordCount => _wordCount;

  bool get isTwelve => _wordCount == 12;
  bool get isEighteen => _wordCount == 18;
  bool get isTwentyFour => _wordCount == 24;

  /// Switch word count and optionally regenerate immediately.
  Future<void> setWordCount(int count, {bool regenerateNow = false}) async {
    if (count != 12 && count != 18 && count != 24) return;
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

  /// Generate a new mnemonic (12, 18, or 24 words) using [StellarWalletServices].
  ///
  /// [wordCountOverride] lets callers request a specific length without
  /// permanently changing [wordCount] on failure.
  Future<void> regenerate({int? wordCountOverride}) async {
    final count = (wordCountOverride == 12 ||
        wordCountOverride == 18 ||
        wordCountOverride == 24)
        ? wordCountOverride!
        : _wordCount;

    try {
      _set(_state.copyWith(loading: true, error: ''));

      // Generate mnemonic based on word count
      final String m;
      switch (count) {
        case 24:
          m = await _svc.generateMnemonic24();
          break;
        case 18:
          m = await _svc.generateMnemonic(wordCount: 18);
          break;
        case 12:
        default:
          m = await _svc.generateMnemonic12();
          break;
      }

      final trimmed = m.trim();
      final words = trimmed.split(RegExp(r'\s+'));

      // Validate word count matches expectation
      if (words.length != count) {
        throw Exception(
          'Generated mnemonic has ${words.length} words, expected $count',
        );
      }

      _set(_state.copyWith(
        loading: false,
        mnemonic: trimmed,
        words: words,
        obscured: true,
        ack1: false,
        ack2: false,
      ));
      _wordCount = count;

      debugPrint('SeedPhraseVM: Generated $count-word mnemonic successfully');
    } catch (e) {
      debugPrint('SeedPhraseVM: Error generating mnemonic: $e');
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

  /// Validate current mnemonic word count
  bool get isValidWordCount {
    final count = _state.words.length;
    return count == 12 || count == 18 || count == 24;
  }

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

    // Validate word count first
    if (!isValidWordCount) {
      _set(_state.copyWith(
        error: 'Invalid recovery phrase. Must be 12, 18, or 24 words.',
      ));
      return false;
    }

    // Validate (async in SDK v3).
    final valid = await _svc.validateMnemonic(phrase);
    if (!valid) {
      _set(_state.copyWith(
        error: 'Please enter a valid 12-, 18-, or 24-word recovery phrase.',
      ));
      return false;
    }

    try {
      _set(_state.copyWith(loading: true, error: ''));

      final publicAddress = await _svc.getAccountIdFromMnemonic(phrase);

      // Add as a new wallet and make it active (does NOT overwrite existing).
      final localId = await SeedStorage.addWallet(
        phrase,
        publicAddress: publicAddress,
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

      try {
        await WalletManager.I.ensureLocalWalletSaved(
          localId: localId,
          setActiveIfCurrent: true,
        );
      } catch (_) {
        // Best effort: wallet_home_screen will retry auto-save later.
      }

      _set(_state.copyWith(loading: false));
      debugPrint('SeedPhraseVM: Saved ${_state.words.length}-word mnemonic successfully');
      return true;
    } catch (e) {
      debugPrint('SeedPhraseVM: Error saving mnemonic: $e');
      _set(_state.copyWith(loading: false, error: 'Unexpected error: $e'));
      return false;
    }
  }

  /// Validate and import an existing mnemonic
  Future<bool> importMnemonic(String mnemonic) async {
    try {
      _set(_state.copyWith(loading: true, error: ''));

      final trimmed = mnemonic.trim();
      final words = trimmed.split(RegExp(r'\s+'));
      final count = words.length;

      // Validate word count
      if (count != 12 && count != 18 && count != 24) {
        _set(_state.copyWith(
          loading: false,
          error: 'Invalid word count. Must be 12, 18, or 24 words.',
        ));
        return false;
      }

      // Validate mnemonic with Stellar SDK
      final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final valid = await _svc.validateMnemonic(normalized);

      if (!valid) {
        _set(_state.copyWith(
          loading: false,
          error: 'Invalid recovery phrase. Please check and try again.',
        ));
        return false;
      }

      // Update state with imported mnemonic
      _set(_state.copyWith(
        loading: false,
        mnemonic: normalized,
        words: words,
        obscured: false,
        ack1: false,
        ack2: false,
      ));

      _wordCount = count;
      debugPrint('SeedPhraseVM: Imported $count-word mnemonic successfully');
      return true;
    } catch (e) {
      debugPrint('SeedPhraseVM: Error importing mnemonic: $e');
      _set(_state.copyWith(
        loading: false,
        error: 'Failed to import phrase: $e',
      ));
      return false;
    }
  }

  /// Get word count display label
  String get wordCountLabel {
    switch (_wordCount) {
      case 24:
        return '24-word';
      case 18:
        return '18-word';
      case 12:
      default:
        return '12-word';
    }
  }

  /// Get security level label based on word count
  String get securityLevel {
    switch (_wordCount) {
      case 24:
        return 'Maximum Security';
      case 18:
        return 'Enhanced Security';
      case 12:
      default:
        return 'Standard Security';
    }
  }

  /// Get entropy bits for current word count
  int get entropyBits {
    switch (_wordCount) {
      case 24:
        return 256;
      case 18:
        return 192;
      case 12:
      default:
        return 128;
    }
  }
}
