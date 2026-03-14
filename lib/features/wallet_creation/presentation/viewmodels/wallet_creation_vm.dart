// lib/features/wallet_creation/viewmodel/wallet_creation_vm.dart
import 'package:flutter/foundation.dart';
import 'package:next_fi/features/wallet_creation/presentation/viewmodels/wallet_creation_state.dart';

class WalletCreationVM extends ChangeNotifier {
  WalletCreationState _state = const WalletCreationState();
  WalletCreationState get state => _state;

  void _set(WalletCreationState s) { _state = s; notifyListeners(); }

  /// Configure per navigation (so the same screen can be splash or not)
  void configure({bool? isSplash, String? logoAsset}) {
    _set(_state.copyWith(isSplash: isSplash, logoAsset: logoAsset));
  }

  /// Back to defaults (avoid leaking state if screen closed)
  void reset() {
    _set(const WalletCreationState());
  }
}
