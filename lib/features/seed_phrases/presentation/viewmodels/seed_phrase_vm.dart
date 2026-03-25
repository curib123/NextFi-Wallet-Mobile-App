import 'package:flutter/foundation.dart';
import 'package:next_fi/features/seed_phrases/presentation/viewmodels/seed_phrase_state.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';

class SeedPhraseVM extends ChangeNotifier {
  SeedPhraseVM({required StellarWalletServices service}) : _svc = service;

  final StellarWalletServices _svc;

  SeedPhraseState _state = const SeedPhraseState();
  SeedPhraseState get state => _state;

  bool _disposed = false;
  Future<bool>? _saveSecurelyFuture;
  String? _lastSavedPublicAddress;

  void _set(SeedPhraseState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int _wordCount = 12;
  int get wordCount => _wordCount;

  bool get isTwelve => _wordCount == 12;
  bool get isEighteen => _wordCount == 18;
  bool get isTwentyFour => _wordCount == 24;

  Future<void> setWordCount(int count, {bool regenerateNow = false}) async {
    if (count != 12 && count != 18 && count != 24) return;
    if (_wordCount == count && !regenerateNow) return;
    _wordCount = count;
    if (regenerateNow) await regenerate();
  }

  Future<void> init() async {
    if (_state.mnemonic.isNotEmpty) return;
    await regenerate();
  }

  Future<void> regenerate({int? wordCountOverride}) async {
    final count =
        (wordCountOverride == 12 ||
            wordCountOverride == 18 ||
            wordCountOverride == 24)
        ? wordCountOverride!
        : _wordCount;

    try {
      _set(_state.copyWith(loading: true, error: ''));

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

      if (words.length != count) {
        throw Exception(
          'Generated mnemonic has ${words.length} words, expected $count',
        );
      }

      _set(
        _state.copyWith(
          loading: false,
          mnemonic: trimmed,
          words: words,
          obscured: true,
          ack1: false,
          ack2: false,
        ),
      );
      _wordCount = count;

      debugPrint('SeedPhraseVM: Generated $count-word mnemonic successfully');
    } catch (e) {
      debugPrint('SeedPhraseVM: Error generating mnemonic: $e');
      _set(
        _state.copyWith(loading: false, error: 'Failed to generate phrase: $e'),
      );
    }
  }

  void toggleObscure() =>
      _set(_state.copyWith(obscured: !_state.obscured, error: ''));

  void forceHide() {
    if (!_state.obscured) _set(_state.copyWith(obscured: true));
  }

  void setAck1(bool v) => _set(_state.copyWith(ack1: v));
  void setAck2(bool v) => _set(_state.copyWith(ack2: v));

  String normalized() =>
      _state.mnemonic.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get readyToSecure =>
      !_state.obscured && _state.ack1 && _state.ack2 && !_state.loading;

  bool get isValidWordCount {
    final count = _state.words.length;
    return count == 12 || count == 18 || count == 24;
  }

  Future<bool> saveSecurely() async {
    final pending = _saveSecurelyFuture;
    if (pending != null) {
      return pending;
    }

    final future = _runSaveSecurely();
    _saveSecurelyFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_saveSecurelyFuture, future)) {
        _saveSecurelyFuture = null;
      }
    }
  }

  Future<bool> _runSaveSecurely() async {
    final phrase = normalized();

    if (!isValidWordCount) {
      _set(
        _state.copyWith(
          error: 'Invalid recovery phrase. Must be 12, 18, or 24 words.',
        ),
      );
      return false;
    }

    final valid = await _svc.validateMnemonic(phrase);
    if (!valid) {
      _set(
        _state.copyWith(
          error: 'Please enter a valid 12-, 18-, or 24-word recovery phrase.',
        ),
      );
      return false;
    }

    try {
      _set(_state.copyWith(loading: true, error: ''));

      final publicAddress = await _svc.getAccountIdFromMnemonic(phrase);
      final existingWalletId = await SeedStorage.findWalletIdByPublicAddress(
        publicAddress,
      );
      if (existingWalletId != null &&
          _lastSavedPublicAddress == publicAddress) {
        await SeedStorage.setActiveWallet(existingWalletId);
        _set(_state.copyWith(loading: false, error: ''));
        return true;
      }

      final localId = await SeedStorage.addWallet(
        phrase,
        publicAddress: publicAddress,
        makeActive: true,
      );

      final stored = await SeedStorage.getActiveSeed();
      if (stored == null || stored.trim().isEmpty) {
        _set(
          _state.copyWith(
            loading: false,
            error: 'Could not verify saved phrase. Please try again.',
          ),
        );
        return false;
      }

      final storedNorm = stored.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (storedNorm != phrase) {
        _set(
          _state.copyWith(
            loading: false,
            error: 'Saved phrase mismatch. Please try again.',
          ),
        );
        return false;
      }

      try {
        await WalletManager.I.ensureLocalWalletSaved(
          localId: localId,
          setActiveIfCurrent: true,
        );
      } catch (_) {}

      _lastSavedPublicAddress = publicAddress;
      _set(_state.copyWith(loading: false));
      debugPrint(
        'SeedPhraseVM: Saved ${_state.words.length}-word mnemonic successfully',
      );
      return true;
    } catch (e) {
      debugPrint('SeedPhraseVM: Error saving mnemonic: $e');
      _set(_state.copyWith(loading: false, error: 'Unexpected error: $e'));
      return false;
    }
  }

  Future<bool> importMnemonic(String mnemonic) async {
    try {
      _set(_state.copyWith(loading: true, error: ''));

      final trimmed = mnemonic.trim();
      final words = trimmed.split(RegExp(r'\s+'));
      final count = words.length;

      if (count != 12 && count != 18 && count != 24) {
        _set(
          _state.copyWith(
            loading: false,
            error: 'Invalid word count. Must be 12, 18, or 24 words.',
          ),
        );
        return false;
      }

      final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final valid = await _svc.validateMnemonic(normalized);

      if (!valid) {
        _set(
          _state.copyWith(
            loading: false,
            error: 'Invalid recovery phrase. Please check and try again.',
          ),
        );
        return false;
      }

      _set(
        _state.copyWith(
          loading: false,
          mnemonic: normalized,
          words: words,
          obscured: false,
          ack1: false,
          ack2: false,
        ),
      );

      _wordCount = count;
      debugPrint('SeedPhraseVM: Imported $count-word mnemonic successfully');
      return true;
    } catch (e) {
      debugPrint('SeedPhraseVM: Error importing mnemonic: $e');
      _set(
        _state.copyWith(loading: false, error: 'Failed to import phrase: $e'),
      );
      return false;
    }
  }

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
