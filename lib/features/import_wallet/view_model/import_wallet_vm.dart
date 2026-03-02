// lib/features/import_wallet/viewmodel/import_wallet_vm.dart
import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// The SDK's WordList class isn't re-exported from the barrel file, so we
// import it directly.  This is the same list the SDK itself uses for
// mnemonic generation / validation, keeping autocomplete consistent.
import 'package:stellar_flutter_sdk/src/sep/0005/word_list.dart';

import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';
import 'package:next_fi/features/import_wallet/model/import_wallet_state.dart';

class ImportWalletVM extends ChangeNotifier {
  ImportWalletState _state = const ImportWalletState();
  ImportWalletState get state => _state;

  bool _disposed = false;

  void _set(ImportWalletState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Word list (cached once)
  // ──────────────────────────────────────────────────────────────────────────

  /// BIP-39 English word list from the SDK (2 048 words).
  static final List<String> _englishWords = WordList.englishWords();

  // ──────────────────────────────────────────────────────────────────────────
  // Text input helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Normalize to lowercase + single spaces.
  String _sanitized(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Update the raw text and compute autocomplete suggestions for the last
  /// (partial) word.
  void updateText(String text) {
    final t = text.trim();
    final words = t.isEmpty ? <String>[] : t.split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last.toLowerCase() : '';

    List<String> suggs = [];
    if (lastWord.isNotEmpty) {
      suggs = _englishWords
          .where((w) => w.startsWith(lastWord))
          .take(6)
          .toList();
    }
    _set(_state.copyWith(rawText: text, suggestions: suggs, error: ''));
  }

  /// Replace the last (partial) word with a suggestion.
  /// Returns the new full text for the controller.
  String replaceLastWord(String current, String word) {
    final t = current.trim();
    final words = t.isEmpty ? <String>[] : t.split(RegExp(r'\s+'));
    if (words.isEmpty) {
      return '$word ';
    }
    words[words.length - 1] = word;
    return '${words.join(' ')} ';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Validation
  // ──────────────────────────────────────────────────────────────────────────

  String get sanitizedPhrase => _sanitized(_state.rawText);

  /// Validate using the SDK's [Wallet.validate] (async, includes checksum
  /// verification).
  Future<bool> validatePhrase() async {
    final phrase = sanitizedPhrase;
    if (phrase.isEmpty) return false;
    try {
      return await Wallet.validate(phrase);
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Import & persist
  // ──────────────────────────────────────────────────────────────────────────

  /// Save the imported phrase, make it the active wallet, and verify
  /// persistence via round-trip read.
  Future<bool> saveImported() async {
    try {
      _set(_state.copyWith(importing: true, error: ''));
      final phrase = sanitizedPhrase;

      // Validate first.
      final valid = await validatePhrase();
      if (!valid) {
        _set(_state.copyWith(
          importing: false,
          error: 'Invalid recovery phrase. Please check and try again.',
        ));
        return false;
      }

      final wallet = await Wallet.from(phrase);
      final publicAddress = await wallet.getAccountId(index: 0);

      final newId = await SeedStorage.addWallet(
        phrase,
        name: 'Imported Wallet',
        publicAddress: publicAddress,
      );
      await SeedStorage.setActiveWallet(newId);

      // Verify round-trip.
      final stored = await SeedStorage.getActiveSeed();
      if (stored == null || stored.trim().isEmpty) {
        _set(_state.copyWith(
          importing: false,
          error: 'Could not verify saved phrase. Please try again.',
        ));
        return false;
      }

      try {
        await WalletManager.I.saveAddressIfMissing(
          publicAddress: publicAddress,
          label: 'Imported Wallet',
        );
      } catch (_) {
        // Best effort: wallet_home_screen will retry auto-save later.
      }

      _set(_state.copyWith(importing: false));
      return true;
    } catch (e) {
      _set(_state.copyWith(
        importing: false,
        error: 'Failed to import wallet. Please try again.',
      ));
      return false;
    }
  }
}
