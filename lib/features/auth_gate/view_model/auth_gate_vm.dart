// lib/features/auth_gate/viewmodel/auth_gate_vm.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:next_fi/Services/security_storage.dart';
import '../model/auth_gate_state.dart';

enum PinStatus {
  needFirstConfirm,
  saved,
  verified,
  mismatch,
  invalid,
  lockedOut,
  storageError,
  error,
}

class PinResult {
  final PinStatus status;
  final Duration? remaining;
  final String? message;
  const PinResult(this.status, {this.remaining, this.message});
}

class BioResult {
  final bool success;
  final String? message;
  const BioResult({required this.success, this.message});
}

class AuthGateVM extends ChangeNotifier {
  AuthGateState _state = const AuthGateState();
  AuthGateState get state => _state;

  final LocalAuthentication _localAuth = LocalAuthentication();
  Timer? _lockoutTimer;

  void _set(AuthGateState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> init() async {
    // Storage ready?
    final ready = await SecurityStorage.ensureReady();
    if (!ready) {
      _set(_state.copyWith(
        isNewUser: true,
        deviceSupportsBiometrics: false,
        biometricsEnabled: false,
        initWarning: "Secure storage unavailable; PIN cannot be saved on this environment.",
      ));
      return;
    }

    // Migrations (safe no-op)
    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'user_pin');
    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'app_pin_v1');

    final hasPin = await SecurityStorage.hasPin();

    // Biometrics capability
    bool canCheck = false, isSupported = false;
    List<BiometricType> available = const [];
    try {
      canCheck = await _localAuth.canCheckBiometrics;
      isSupported = await _localAuth.isDeviceSupported();
      available = await _localAuth.getAvailableBiometrics();
    } catch (_) {}

    final bioEnabled = await SecurityStorage.isBiometricsEnabled();
    final rem = await SecurityStorage.lockoutRemaining();

    _set(_state.copyWith(
      isNewUser: !hasPin,
      deviceSupportsBiometrics: (canCheck || isSupported) && available.isNotEmpty,
      biometricsEnabled: bioEnabled,
      lockoutRemaining: rem,
      initWarning: null,
    ));

    _startOrStopLockoutTimer(rem);
  }

  void disposeTimers() {
    _lockoutTimer?.cancel();
  }

  void toggleObscurePin() => _set(_state.copyWith(obscurePin: !_state.obscurePin));

  Future<void> refreshLockout() async {
    final rem = await SecurityStorage.lockoutRemaining();
    _set(_state.copyWith(lockoutRemaining: rem));
    _startOrStopLockoutTimer(rem);
  }

  void _startOrStopLockoutTimer(Duration? remaining) {
    _lockoutTimer?.cancel();
    if (remaining == null || remaining <= Duration.zero) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final rem = await SecurityStorage.lockoutRemaining();
      if (rem == null || rem <= Duration.zero) {
        t.cancel();
        _set(_state.copyWith(lockoutRemaining: null));
      } else {
        _set(_state.copyWith(lockoutRemaining: rem));
      }
    });
  }

  bool get isLockedOut =>
      _state.lockoutRemaining != null && _state.lockoutRemaining! > Duration.zero;

  Future<BioResult> authenticateWithBiometrics() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) {
        await SecurityStorage.markSuccessfulAuth();
        _set(_state.copyWith(unlockedVisual: true));
        return const BioResult(success: true, message: "Authentication successful");
      }
      return const BioResult(success: false, message: "Biometric authentication failed");
    } on PlatformException catch (e) {
      final code = e.code;
      if (_state.biometricsEnabled &&
          (code == 'NotEnrolled' || code == 'NotAvailable' || code == 'PasscodeNotSet')) {
        await SecurityStorage.setBiometricsEnabled(false);
        _set(_state.copyWith(biometricsEnabled: false));
      }
      return BioResult(success: false, message: "Biometric error: $code");
    } catch (e) {
      return BioResult(success: false, message: "Biometric error: $e");
    }
  }

  /// Returns a [PinResult] describing what happened.
  Future<PinResult> submitPin(String raw) async {
    if (isLockedOut) {
      final rem = _state.lockoutRemaining!;
      return PinResult(PinStatus.lockedOut, remaining: rem,
          message: "Too many attempts. Try again in ${_fmt(rem)}.");
    }

    final pin = raw.replaceAll(RegExp(r'\D'), '');
    if (pin.length != 6) {
      return const PinResult(PinStatus.error, message: "PIN must be exactly 6 digits");
    }

    _set(_state.copyWith(submitting: true));

    try {
      if (_state.isNewUser) {
        // step 1: collect first entry
        if (_state.firstPinEntry == null) {
          _set(_state.copyWith(firstPinEntry: pin, submitting: false));
          return const PinResult(PinStatus.needFirstConfirm, message: "Re-enter your PIN to confirm");
        }

        // step 2: confirm
        if (pin != _state.firstPinEntry) {
          _set(_state.copyWith(firstPinEntry: null, submitting: false));
          return const PinResult(PinStatus.mismatch, message: "PINs do not match. Please try again.");
        }

        await SecurityStorage.setPin(pin);
        final saved = await SecurityStorage.hasPin();
        if (!saved) {
          _set(_state.copyWith(submitting: false));
          return const PinResult(PinStatus.storageError,
              message: "Couldn’t persist PIN. Try again (or disable private mode).");
        }

        _set(_state.copyWith(
          isNewUser: false,
          firstPinEntry: null,
          submitting: false,
          unlockedVisual: true,
        ));
        return const PinResult(PinStatus.saved, message: "PIN saved successfully");
      }

      // Existing user
      final ok = await SecurityStorage.verifyPin(pin);
      if (ok) {
        _set(_state.copyWith(submitting: false, unlockedVisual: true));
        return const PinResult(PinStatus.verified, message: "PIN verified successfully");
      }

      // Wrong pin → refresh lockout
      final rem = await SecurityStorage.lockoutRemaining();
      _set(_state.copyWith(lockoutRemaining: rem, submitting: false));
      if (rem != null && rem > Duration.zero) {
        _startOrStopLockoutTimer(rem);
        return PinResult(PinStatus.lockedOut, remaining: rem,
            message: "Too many attempts. Try again in ${_fmt(rem)}.");
      }
      return const PinResult(PinStatus.invalid, message: "Invalid PIN");
    } catch (e) {
      _set(_state.copyWith(submitting: false));
      return PinResult(PinStatus.error, message: "Error: $e");
    }
  }

  /// Call once after init (e.g., on first frame or resume).
  Future<BioResult?> maybeAutoBiometric() async {
    if (_state.autoBioTried) return null;
    if (!_state.isNewUser && _state.deviceSupportsBiometrics && _state.biometricsEnabled && !isLockedOut) {
      _set(_state.copyWith(autoBioTried: true));
      return authenticateWithBiometrics();
    }
    _set(_state.copyWith(autoBioTried: true));
    return null;
  }

  static String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}
