import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:next_fi/features/settings/presentation/viewmodels/settings_vm.dart';

class _FakeSettingsSecurityStore implements SettingsSecurityStore {
  _FakeSettingsSecurityStore({
    this.hasPinValue = true,
    this.biometricsEnabledValue = false,
    this.authGateEnabledValue = true,
  });

  bool hasPinValue;
  bool biometricsEnabledValue;
  bool authGateEnabledValue;
  final List<bool> authGateWrites = <bool>[];
  final List<bool> biometricWrites = <bool>[];

  @override
  Future<bool> ensureReady() async => true;

  @override
  Future<bool> hasPin() async => hasPinValue;

  @override
  Future<bool> isBiometricsEnabled() async => biometricsEnabledValue;

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    biometricsEnabledValue = enabled;
    biometricWrites.add(enabled);
  }

  @override
  Future<bool> isAuthGateEnabled() async => authGateEnabledValue;

  @override
  Future<void> setAuthGateEnabled(bool enabled) async {
    authGateEnabledValue = enabled;
    authGateWrites.add(enabled);
  }
}

class _FakeLocalAuthentication extends LocalAuthentication {
  _FakeLocalAuthentication({
    this.canCheck = true,
    this.supported = true,
    this.availableBiometrics = const <BiometricType>[BiometricType.strong],
  });

  final bool canCheck;
  final bool supported;
  final List<BiometricType> availableBiometrics;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return availableBiometrics;
  }
}

void main() {
  group('SettingsVM app lock', () {
    late BuildContext context;

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    testWidgets('toggling app lock off triggers auth before persistence', (
      WidgetTester tester,
    ) async {
      await pumpHost(tester);
      final store = _FakeSettingsSecurityStore(authGateEnabledValue: true);
      final completer = Completer<bool>();
      var authCalls = 0;
      final vm = SettingsVM(
        localAuth: _FakeLocalAuthentication(),
        securityStore: store,
        protectedAuthGateChallenge: (_) {
          authCalls += 1;
          return completer.future;
        },
      );

      unawaited(vm.onToggleAuthGate(context, false));
      await tester.pump();

      expect(authCalls, 1);
      expect(vm.authGateEnabled, isTrue);
      expect(vm.authGateToggleInProgress, isTrue);
      expect(store.authGateWrites, isEmpty);

      completer.complete(true);
      await tester.pumpAndSettle();

      expect(vm.authGateEnabled, isFalse);
      expect(store.authGateWrites, <bool>[false]);
    });

    testWidgets('auth failure keeps app lock enabled', (
      WidgetTester tester,
    ) async {
      await pumpHost(tester);
      final store = _FakeSettingsSecurityStore(authGateEnabledValue: true);
      final vm = SettingsVM(
        localAuth: _FakeLocalAuthentication(),
        securityStore: store,
        protectedAuthGateChallenge: (_) async => false,
      );

      await vm.onToggleAuthGate(context, false);

      expect(vm.authGateEnabled, isTrue);
      expect(store.authGateWrites, isEmpty);
    });

    testWidgets('auth cancel keeps app lock enabled', (
      WidgetTester tester,
    ) async {
      await pumpHost(tester);
      final store = _FakeSettingsSecurityStore(authGateEnabledValue: true);
      final vm = SettingsVM(
        localAuth: _FakeLocalAuthentication(),
        securityStore: store,
        protectedAuthGateChallenge: (_) async => false,
      );

      await vm.onToggleAuthGate(context, false);

      expect(vm.authGateEnabled, isTrue);
      expect(store.authGateWrites, isEmpty);
    });

    testWidgets('rapid repeated taps do not open a second auth flow', (
      WidgetTester tester,
    ) async {
      await pumpHost(tester);
      final store = _FakeSettingsSecurityStore(authGateEnabledValue: true);
      final completer = Completer<bool>();
      var authCalls = 0;
      final vm = SettingsVM(
        localAuth: _FakeLocalAuthentication(),
        securityStore: store,
        protectedAuthGateChallenge: (_) {
          authCalls += 1;
          return completer.future;
        },
      );

      unawaited(vm.onToggleAuthGate(context, false));
      unawaited(vm.onToggleAuthGate(context, false));
      await tester.pump();

      expect(authCalls, 1);
      expect(store.authGateWrites, isEmpty);

      completer.complete(false);
      await tester.pumpAndSettle();

      expect(vm.authGateEnabled, isTrue);
      expect(store.authGateWrites, isEmpty);
    });

    testWidgets('biometric enable reuses the protected auth challenge', (
      WidgetTester tester,
    ) async {
      await pumpHost(tester);
      final store = _FakeSettingsSecurityStore(
        hasPinValue: true,
        authGateEnabledValue: true,
      );
      var authCalls = 0;
      final vm = SettingsVM(
        localAuth: _FakeLocalAuthentication(),
        securityStore: store,
        protectedAuthGateChallenge: (_) async {
          authCalls += 1;
          return true;
        },
      );

      await vm.onToggleBiometrics(context, true);

      expect(authCalls, 1);
      expect(vm.biometricsEnabled, isTrue);
      expect(store.biometricWrites, <bool>[true]);
    });
  });
}
