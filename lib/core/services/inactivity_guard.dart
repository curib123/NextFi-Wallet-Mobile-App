import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';

class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 2),
  });

  final Widget child;
  final Duration idleTimeout;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  DateTime _lastActivityAt = DateTime.now();
  bool _hasLockedSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleIdleTimer(widget.idleTimeout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InactivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idleTimeout != widget.idleTimeout) {
      _scheduleIdleTimer(widget.idleTimeout);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_shell.authGateEnabled || !_shell.hasPin) {
        _scheduleIdleTimer(widget.idleTimeout);
        return;
      }
      final Duration idleFor = DateTime.now().difference(_lastActivityAt);
      if (_shouldProtectSession && idleFor >= widget.idleTimeout) {
        _lockSession();
      } else {
        _scheduleIdleTimer(widget.idleTimeout - idleFor);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _idleTimer?.cancel();
      if (_shouldProtectSession) {
        _lockSession(showSnackBar: false);
      }
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

  void _markActivity() {
    if (!mounted || !_shouldProtectSession) return;
    _hasLockedSession = false;
    _lastActivityAt = DateTime.now();
    _scheduleIdleTimer(widget.idleTimeout);
  }

  void _scheduleIdleTimer(Duration duration) {
    _idleTimer?.cancel();
    if (!_shouldProtectSession || _hasLockedSession) return;

    final Duration safeDuration = duration <= Duration.zero
        ? const Duration(milliseconds: 50)
        : duration;
    _idleTimer = Timer(safeDuration, _lockSession);
  }

  void _lockSession({bool showSnackBar = true}) {
    if (!mounted || !_shouldProtectSession || _hasLockedSession) return;

    _hasLockedSession = true;
    _idleTimer?.cancel();
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
        _lastActivityAt = DateTime.now();
        _hasLockedSession = false;
        _scheduleIdleTimer(widget.idleTimeout);
      } else {
        if (!next.authGateEnabled || !next.hasPin) {
          _hasLockedSession = false;
        }
        _idleTimer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markActivity(),
      onPointerMove: (_) => _markActivity(),
      onPointerUp: (_) => _markActivity(),
      onPointerSignal: (_) => _markActivity(),
      child: widget.child,
    );
  }
}
