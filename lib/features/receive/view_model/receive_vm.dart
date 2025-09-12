// lib/features/receive/viewmodel/receive_vm.dart
import 'package:flutter/foundation.dart';
import '../model/receive_state.dart';

class ReceiveVM extends ChangeNotifier {
  ReceiveState _state;
  ReceiveVM({
    required String address,
    required double xlmBalance,
    required double usdcBalance,
    String initialToken = 'XLM',
  }) : _state = ReceiveState(
    address: address,
    xlmBalance: xlmBalance,
    usdcBalance: usdcBalance,
    xlmSelected: initialToken.toUpperCase() != 'USDC',
  );

  ReceiveState get state => _state;
  void _set(ReceiveState s) { _state = s; notifyListeners(); }

  void selectXLM() => _set(_state.copyWith(xlmSelected: true));
  void selectUSDC() => _set(_state.copyWith(xlmSelected: false));

  String get token => _state.token;

  String get safetyNote => _state.xlmSelected
      ? 'Send only XLM (native Stellar) to this address. Sending other assets or from other networks may result in permanent loss.'
      : 'Send only USDC on the Stellar network to this address. A USDC trustline is required to receive funds.';
}
