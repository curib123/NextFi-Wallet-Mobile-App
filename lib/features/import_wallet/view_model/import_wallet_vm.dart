// lib/features/import_wallet/viewmodel/import_wallet_vm.dart
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip39/src/wordlists/english.dart' as english;
import 'package:next_fi/Services/seed_storage.dart';

import '../model/import_wallet_state.dart';

class ImportWalletVM extends ChangeNotifier {
  ImportWalletState _state = const ImportWalletState();
  ImportWalletState get state => _state;

  void _set(ImportWalletState s) { _state = s; notifyListeners(); }

  // Sanitize helper (lowercase + single spaces)
  String _sanitized(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // Update text + compute suggestions
  void updateText(String text) {
    final t = text.trim();
    final words = t.isEmpty ? <String>[] : t.split(RegExp(r'\s+'));
    final lastWord = words.isNotEmpty ? words.last.toLowerCase() : "";

    List<String> suggs = [];
    if (lastWord.isNotEmpty) {
      suggs = english.WORDLIST.where((w) => w.startsWith(lastWord)).take(6).toList();
    }
    _set(_state.copyWith(rawText: text, suggestions: suggs, error: ''));
  }

  // Replace the last (partial) word with a suggestion; returns new text for the controller
  String replaceLastWord(String current, String word) {
    final t = current.trim();
    final words = t.isEmpty ? <String>[] : t.split(RegExp(r'\s+'));
    if (words.isEmpty) {
      return "$word ";
    } else {
      words[words.length - 1] = word;
      return "${words.join(' ')} ";
    }
  }

  String get sanitizedPhrase => _sanitized(_state.rawText);

  bool validatePhrase() => bip39.validateMnemonic(sanitizedPhrase);

  // Save + activate imported wallet, then verify it round-trip
  Future<bool> saveImported() async {
    try {
      _set(_state.copyWith(importing: true, error: ''));
      final phrase = sanitizedPhrase;

      final newId = await SeedStorage.addWallet(phrase, name: 'Imported Wallet');
      await SeedStorage.setActiveWallet(newId);

      final stored = await SeedStorage.getActiveSeed();
      if (stored == null || stored.isEmpty) {
        _set(_state.copyWith(importing: false, error: 'Could not verify saved phrase. Please try again.'));
        return false;
      }

      _set(_state.copyWith(importing: false));
      return true;
    } catch (e) {
      _set(_state.copyWith(importing: false, error: 'Failed to import wallet. Please try again.'));
      return false;
    }
  }
}
