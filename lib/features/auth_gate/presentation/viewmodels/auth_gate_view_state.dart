import 'package:next_fi/features/auth_gate/presentation/viewmodels/auth_gate_state.dart';

class AuthGateViewState {
  const AuthGateViewState({
    this.flow = const AuthGateState(),
    this.currentPin = '',
    this.coverImageUrl,
    this.initialized = false,
  });

  final AuthGateState flow;
  final String currentPin;
  final String? coverImageUrl;
  final bool initialized;

  bool get isLockedOut =>
      flow.lockoutRemaining != null && flow.lockoutRemaining! > Duration.zero;

  int get currentPinLength => currentPin.length;

  AuthGateViewState copyWith({
    AuthGateState? flow,
    String? currentPin,
    Object? coverImageUrl = _sentinel,
    bool? initialized,
  }) {
    return AuthGateViewState(
      flow: flow ?? this.flow,
      currentPin: currentPin ?? this.currentPin,
      coverImageUrl: identical(coverImageUrl, _sentinel)
          ? this.coverImageUrl
          : coverImageUrl as String?,
      initialized: initialized ?? this.initialized,
    );
  }
}

const Object _sentinel = Object();
