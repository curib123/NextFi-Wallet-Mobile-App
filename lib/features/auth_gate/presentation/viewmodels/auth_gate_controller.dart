import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/auth_gate/presentation/viewmodels/auth_gate_view_state.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';

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
  const PinResult(this.status, {this.remaining, this.message});

  final PinStatus status;
  final Duration? remaining;
  final String? message;
}

class BioResult {
  const BioResult({required this.success, this.message});

  final bool success;
  final String? message;
}

final authGateLocalAuthProvider = Provider<LocalAuthentication>(
  (Ref ref) => LocalAuthentication(),
);

final authGateControllerProvider =
    NotifierProvider.autoDispose<AuthGateController, AuthGateViewState>(
      AuthGateController.new,
    );

class AuthGateController extends Notifier<AuthGateViewState> {
  Timer? _lockoutTimer;
  bool _biometricInProgress = false;
  Future<void>? _initializeFuture;

  @override
  AuthGateViewState build() {
    ref.onDispose(() {
      _lockoutTimer?.cancel();
    });
    Future<void>.microtask(initialize);
    return const AuthGateViewState();
  }

  Future<void> initialize() async {
    if (state.initialized) return;
    final pending = _initializeFuture;
    if (pending != null) return pending;

    _initializeFuture = _runInitialize();
    try {
      await _initializeFuture;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> refreshLockout() async {
    final rem = await SecurityStorage.lockoutRemaining();
    state = state.copyWith(flow: state.flow.copyWith(lockoutRemaining: rem));
    _startOrStopLockoutTimer(rem);
  }

  Future<void> refreshAppCover() async {
    await _loadAppCover();
  }

  Future<void> setBiometricsEnabled(bool enable) async {
    if (enable) {
      if (state.flow.isNewUser || !state.flow.deviceSupportsBiometrics) return;
      await SecurityStorage.setBiometricsEnabled(true);
      state = state.copyWith(
        flow: state.flow.copyWith(biometricsEnabled: true),
      );
      return;
    }

    await SecurityStorage.setBiometricsEnabled(false);
    state = state.copyWith(flow: state.flow.copyWith(biometricsEnabled: false));
  }

  void toggleObscurePin() {
    state = state.copyWith(
      flow: state.flow.copyWith(obscurePin: !state.flow.obscurePin),
    );
  }

  bool onNumberPressed(String number) {
    if (state.currentPin.length >= 6 ||
        state.isLockedOut ||
        state.flow.submitting) {
      return false;
    }
    state = state.copyWith(currentPin: '${state.currentPin}$number');
    return state.currentPin.length == 6;
  }

  void onBackspacePressed() {
    if (state.currentPin.isEmpty || state.flow.submitting) return;
    state = state.copyWith(
      currentPin: state.currentPin.substring(0, state.currentPin.length - 1),
    );
  }

  void clearCurrentPin() {
    if (state.currentPin.isEmpty) return;
    state = state.copyWith(currentPin: '');
  }

  Future<BioResult> authenticateWithBiometrics() async {
    if (_biometricInProgress) {
      return const BioResult(success: false);
    }
    _biometricInProgress = true;
    try {
      final ok = await ref
          .read(authGateLocalAuthProvider)
          .authenticate(
            localizedReason: 'Authenticate to continue',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
              useErrorDialogs: true,
            ),
          );
      if (ok) {
        await SecurityStorage.markSuccessfulAuth();
        state = state.copyWith(flow: state.flow.copyWith(unlockedVisual: true));
        return const BioResult(
          success: true,
          message: 'Authentication successful',
        );
      }
      return const BioResult(
        success: false,
        message: 'Biometric authentication failed',
      );
    } on PlatformException catch (e) {
      final code = e.code;
      if (state.flow.biometricsEnabled &&
          (code == 'NotEnrolled' ||
              code == 'NotAvailable' ||
              code == 'PasscodeNotSet')) {
        await SecurityStorage.setBiometricsEnabled(false);
        state = state.copyWith(
          flow: state.flow.copyWith(biometricsEnabled: false),
        );
      }
      return BioResult(success: false, message: 'Biometric error: $code');
    } catch (e) {
      return BioResult(success: false, message: 'Biometric error: $e');
    } finally {
      _biometricInProgress = false;
    }
  }

  Future<PinResult> submitCurrentPin() async {
    if (state.isLockedOut) {
      final rem = state.flow.lockoutRemaining!;
      return PinResult(
        PinStatus.lockedOut,
        remaining: rem,
        message: 'Too many attempts. Try again in ${_fmt(rem)}.',
      );
    }

    final pin = state.currentPin.replaceAll(RegExp(r'\D'), '');
    if (pin.length != 6) {
      return const PinResult(
        PinStatus.error,
        message: 'PIN must be exactly 6 digits',
      );
    }

    state = state.copyWith(flow: state.flow.copyWith(submitting: true));

    try {
      if (state.flow.isNewUser) {
        if (state.flow.firstPinEntry == null) {
          state = state.copyWith(
            flow: state.flow.copyWith(firstPinEntry: pin, submitting: false),
          );
          return const PinResult(
            PinStatus.needFirstConfirm,
            message: 'Re-enter your PIN to confirm',
          );
        }

        if (pin != state.flow.firstPinEntry) {
          state = state.copyWith(
            flow: state.flow.copyWith(firstPinEntry: null, submitting: false),
          );
          return const PinResult(
            PinStatus.mismatch,
            message: 'PINs do not match. Please try again.',
          );
        }

        await SecurityStorage.setPin(pin);
        final saved = await SecurityStorage.hasPin();
        if (!saved) {
          state = state.copyWith(flow: state.flow.copyWith(submitting: false));
          return const PinResult(
            PinStatus.storageError,
            message:
                'Could not persist PIN. Try again (or disable private mode).',
          );
        }

        state = state.copyWith(
          flow: state.flow.copyWith(
            isNewUser: false,
            firstPinEntry: null,
            submitting: false,
            unlockedVisual: true,
          ),
        );
        return const PinResult(
          PinStatus.saved,
          message: 'PIN saved successfully',
        );
      }

      final ok = await SecurityStorage.verifyPin(pin);
      if (ok) {
        state = state.copyWith(
          flow: state.flow.copyWith(submitting: false, unlockedVisual: true),
        );
        return const PinResult(
          PinStatus.verified,
          message: 'PIN verified successfully',
        );
      }

      final rem = await SecurityStorage.lockoutRemaining();
      state = state.copyWith(
        flow: state.flow.copyWith(lockoutRemaining: rem, submitting: false),
      );
      if (rem != null && rem > Duration.zero) {
        _startOrStopLockoutTimer(rem);
        return PinResult(
          PinStatus.lockedOut,
          remaining: rem,
          message: 'Too many attempts. Try again in ${_fmt(rem)}.',
        );
      }
      return const PinResult(PinStatus.invalid, message: 'Invalid PIN');
    } catch (e) {
      state = state.copyWith(flow: state.flow.copyWith(submitting: false));
      return PinResult(PinStatus.error, message: 'Error: $e');
    }
  }

  Future<BioResult?> maybeAutoBiometric() async {
    if (state.flow.autoBioTried) return null;
    if (!state.flow.isNewUser &&
        state.flow.deviceSupportsBiometrics &&
        state.flow.biometricsEnabled &&
        !state.isLockedOut) {
      state = state.copyWith(flow: state.flow.copyWith(autoBioTried: true));
      return authenticateWithBiometrics();
    }
    return null;
  }

  Future<void> _loadAppCover() async {
    try {
      if (kDebugMode) {
        debugPrint('[AuthGateCover] Fetching app cover config...');
      }
      final config = await ref.read(appCoverServiceProvider).getCurrent();
      if (kDebugMode) {
        debugPrint(
          '[AuthGateCover] Fetch result: '
          'visible=${config?.isVisible} '
          'usable=${config?.hasUsableImage} '
          'url=${config?.imageUrl ?? 'null'}',
        );
      }
      if (!ref.mounted) return;
      final resolvedUrl = config?.hasUsableImage == true
          ? config!.imageUrl
          : null;
      if (kDebugMode) {
        debugPrint(
          '[AuthGateCover] Applying coverImageUrl=${resolvedUrl ?? 'null'}',
        );
      }
      state = state.copyWith(coverImageUrl: resolvedUrl);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AuthGateCover] Fetch failed: $e');
        debugPrint('$stackTrace');
      }
      if (!ref.mounted) return;
      state = state.copyWith(coverImageUrl: null);
    }
  }

  Future<void> _runInitialize() async {
    await _loadAppCover();

    final ready = await SecurityStorage.ensureReady();
    if (!ref.mounted) return;
    if (!ready) {
      state = state.copyWith(
        flow: state.flow.copyWith(
          isNewUser: true,
          deviceSupportsBiometrics: false,
          biometricsEnabled: false,
          initWarning:
              'Secure storage unavailable; PIN cannot be saved on this environment.',
        ),
        initialized: true,
      );
      return;
    }

    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'user_pin');
    await SecurityStorage.migrateLegacyPlaintextPin(legacyKey: 'app_pin_v1');

    final hasPin = await SecurityStorage.hasPin();

    var canCheck = false;
    var isSupported = false;
    List<BiometricType> available = const [];
    try {
      final localAuth = ref.read(authGateLocalAuthProvider);
      canCheck = await localAuth.canCheckBiometrics;
      isSupported = await localAuth.isDeviceSupported();
      available = await localAuth.getAvailableBiometrics();
    } catch (_) {}

    final bioEnabled = await SecurityStorage.isBiometricsEnabled();
    final rem = await SecurityStorage.lockoutRemaining();
    if (!ref.mounted) return;

    state = state.copyWith(
      flow: state.flow.copyWith(
        isNewUser: !hasPin,
        deviceSupportsBiometrics:
            (canCheck || isSupported) && available.isNotEmpty,
        biometricsEnabled: bioEnabled,
        lockoutRemaining: rem,
        initWarning: null,
      ),
      initialized: true,
    );

    _startOrStopLockoutTimer(rem);
  }

  void _startOrStopLockoutTimer(Duration? remaining) {
    _lockoutTimer?.cancel();
    if (remaining == null || remaining <= Duration.zero) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final rem = await SecurityStorage.lockoutRemaining();
      if (rem == null || rem <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(
          flow: state.flow.copyWith(lockoutRemaining: null),
        );
      } else {
        state = state.copyWith(
          flow: state.flow.copyWith(lockoutRemaining: rem),
        );
      }
    });
  }

  String _fmt(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes <= 0) return '${seconds}s';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
