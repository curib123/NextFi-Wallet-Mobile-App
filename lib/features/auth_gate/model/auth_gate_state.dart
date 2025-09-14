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

  static const Object _unset = Object();

  /// For nullable fields, use [Object?] with a private sentinel so we can
  /// distinguish "not provided" from "explicitly set to null".
  AuthGateState copyWith({
    bool? isNewUser,
    bool? deviceSupportsBiometrics,
    bool? biometricsEnabled,
    bool? obscurePin,
    bool? submitting,
    bool? unlockedVisual,
    Object? firstPinEntry = _unset,     // String?
    Object? lockoutRemaining = _unset,  // Duration?
    bool? autoBioTried,
    Object? initWarning = _unset,       // String?
  }) {
    return AuthGateState(
      isNewUser: isNewUser ?? this.isNewUser,
      deviceSupportsBiometrics:
      deviceSupportsBiometrics ?? this.deviceSupportsBiometrics,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      obscurePin: obscurePin ?? this.obscurePin,
      submitting: submitting ?? this.submitting,
      unlockedVisual: unlockedVisual ?? this.unlockedVisual,
      firstPinEntry: identical(firstPinEntry, _unset)
          ? this.firstPinEntry
          : firstPinEntry as String?,
      lockoutRemaining: identical(lockoutRemaining, _unset)
          ? this.lockoutRemaining
          : lockoutRemaining as Duration?,
      autoBioTried: autoBioTried ?? this.autoBioTried,
      initWarning: identical(initWarning, _unset)
          ? this.initWarning
          : initWarning as String?,
    );
  }
}
