import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:stellar_flutter_sdk/src/sep/0005/word_list.dart';

import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';
import 'package:next_fi/features/import_wallet/presentation/viewmodels/import_wallet_state.dart';

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

  static final List<String> _englishWords = WordList.englishWords();

  String _sanitized(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

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

  String replaceLastWord(String current, String word) {
    final t = current.trim();
    final words = t.isEmpty ? <String>[] : t.split(RegExp(r'\s+'));
    if (words.isEmpty) {
      return '$word ';
    }
    words[words.length - 1] = word;
    return '${words.join(' ')} ';
  }

  String get sanitizedPhrase => _sanitized(_state.rawText);

  Future<bool> validatePhrase() async {
    final phrase = sanitizedPhrase;
    if (phrase.isEmpty) return false;
    try {
      return await Wallet.validate(phrase);
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveImported() async {
    try {
      _set(_state.copyWith(importing: true, error: ''));
      final phrase = sanitizedPhrase;

      final valid = await validatePhrase();
      if (!valid) {
        _set(
          _state.copyWith(
            importing: false,
            error: 'Invalid recovery phrase. Please check and try again.',
          ),
        );
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

      final stored = await SeedStorage.getActiveSeed();
      if (stored == null || stored.trim().isEmpty) {
        _set(
          _state.copyWith(
            importing: false,
            error: 'Could not verify saved phrase. Please try again.',
          ),
        );
        return false;
      }

      try {
        await WalletManager.I.ensureLocalWalletSaved(
          localId: newId,
          setActiveIfCurrent: true,
        );
      } catch (_) {}

      _set(_state.copyWith(importing: false));
      return true;
    } catch (e) {
      _set(
        _state.copyWith(
          importing: false,
          error: 'Failed to import wallet. Please try again.',
        ),
      );
      return false;
    }
  }
}
