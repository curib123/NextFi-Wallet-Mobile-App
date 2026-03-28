import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';

class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 2),
    this.now,
  });

  final Widget child;
  final Duration idleTimeout;
  final DateTime Function()? now;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _hasLockedSession = false;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;

      if (!_shell.authGateEnabled || !_shell.hasPin || backgroundedAt == null) {
        return;
      }

      final inactiveFor = _now().difference(backgroundedAt);
      if (_shouldProtectSession && inactiveFor >= widget.idleTimeout) {
        _lockSession();
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt ??= _now();
    }
  }

  AppShellState get _shell => ref.read(appShellProvider);

  bool get _shouldProtectSession {
    return _shell.hasMnemonic &&
        !_shell.loading &&
        !_shell.showSplash &&
        !_shell.showOnboarding &&
        _shell.hasPin &&
        _shell.authGateEnabled &&
        _shell.isAuthenticated;
  }

  void _lockSession({bool showSnackBar = true}) {
    if (!mounted || !_shouldProtectSession || _hasLockedSession) return;

    _hasLockedSession = true;
    _backgroundedAt = null;
    ref.read(appShellProvider.notifier).setAuthenticated(false);

    if (showSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showFloatingSnackBar(
          context,
          message: 'Session locked due to inactivity.',
          type: SnackBarType.warning,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShellState>(appShellProvider, (prev, next) {
      if (next.isAuthenticated && next.authGateEnabled && next.hasPin) {
        _backgroundedAt = null;
        _hasLockedSession = false;
      } else {
        if (!next.authGateEnabled || !next.hasPin) {
          _backgroundedAt = null;
          _hasLockedSession = false;
        }
      }
    });

    return widget.child;
  }
}
