import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/services/inactivity_guard.dart';

class _TestAppShellController extends AppShellController {
  _TestAppShellController(this._initialState);

  final AppShellState _initialState;

  @override
  AppShellState build() => _initialState;
}

void main() {
  const protectedShellState = AppShellState(
    showSplash: false,
    loading: false,
    hasMnemonic: true,
    isAuthenticated: true,
    showOnboarding: false,
    hasPin: true,
    authGateEnabled: true,
  );

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        appShellProvider.overrideWith(
          () => _TestAppShellController(protectedShellState),
        ),
      ],
    );
  }

  Future<void> pumpGuard(
    WidgetTester tester,
    ProviderContainer container,
    DateTime Function() now,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: InactivityGuard(
              idleTimeout: const Duration(minutes: 5),
              now: now,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('InactivityGuard', () {
    testWidgets(
      'does not require auth again while user stays in the foreground past timeout',
      (tester) async {
        final container = createContainer();
        var currentTime = DateTime(2026, 1, 1, 12);
        addTearDown(container.dispose);

        await pumpGuard(tester, container, () => currentTime);
        currentTime = currentTime.add(const Duration(minutes: 6));
        await tester.pump();

        expect(container.read(appShellProvider).isAuthenticated, isTrue);
      },
    );

    testWidgets('locks only after app stays inactive beyond the timeout', (
      tester,
    ) async {
      final container = createContainer();
      var currentTime = DateTime(2026, 1, 1, 12);
      addTearDown(container.dispose);

      await pumpGuard(tester, container, () => currentTime);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(appShellProvider).isAuthenticated, isTrue);

      currentTime = currentTime.add(const Duration(minutes: 4));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(appShellProvider).isAuthenticated, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      currentTime = currentTime.add(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(appShellProvider).isAuthenticated, isFalse);
    });
  });
}
