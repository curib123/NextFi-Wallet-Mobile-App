// lib/features/auth_gate/model/auth_gate_state.dart
import 'package:flutter/material.dart';

@immutable
class AuthGateState {
  final bool isNewUser;
  final bool deviceSupportsBiometrics;
  final bool biometricsEnabled;
  final bool obscurePin;
  final bool submitting;
  final bool unlockedVisual;
  final String? firstPinEntry;
  final Duration? lockoutRemaining;
  final bool autoBioTried;
  final String? initWarning;

  const AuthGateState({
    this.isNewUser = false,
    this.deviceSupportsBiometrics = false,
    this.biometricsEnabled = false,
    this.obscurePin = true,
    this.submitting = false,
    this.unlockedVisual = false,
    this.firstPinEntry,
    this.lockoutRemaining,
    this.autoBioTried = false,
    this.initWarning,
  });

  AuthGateState copyWith({
    bool? isNewUser,
    bool? deviceSupportsBiometrics,
    bool? biometricsEnabled,
    bool? obscurePin,
    bool? submitting,
    bool? unlockedVisual,
    String? firstPinEntry,
    Duration? lockoutRemaining,
    bool? autoBioTried,
    String? initWarning,
  }) {
    return AuthGateState(
      isNewUser: isNewUser ?? this.isNewUser,
      deviceSupportsBiometrics: deviceSupportsBiometrics ?? this.deviceSupportsBiometrics,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      obscurePin: obscurePin ?? this.obscurePin,
      submitting: submitting ?? this.submitting,
      unlockedVisual: unlockedVisual ?? this.unlockedVisual,
      firstPinEntry: firstPinEntry == null && !(_sentinel(firstPinEntry))
          ? this.firstPinEntry
          : firstPinEntry,
      lockoutRemaining: lockoutRemaining == null && !(_sentinel(lockoutRemaining))
          ? this.lockoutRemaining
          : lockoutRemaining,
      autoBioTried: autoBioTried ?? this.autoBioTried,
      initWarning: initWarning == null && !(_sentinel(initWarning))
          ? this.initWarning
          : initWarning,
    );
  }
}

bool _sentinel(Object? _) => true;
