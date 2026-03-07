import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class InactivityGuard extends StatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 2),
  });

  final Widget child;
  final Duration idleTimeout;

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  bool _isWarningVisible = false;
  late DateTime _lastActivityAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivityAt = DateTime.now();
    _scheduleIdleTimer(widget.idleTimeout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final idleFor = DateTime.now().difference(_lastActivityAt);
      final remaining = widget.idleTimeout - idleFor;
      if (remaining <= Duration.zero) {
        _onIdleTimeout();
      } else {
        _scheduleIdleTimer(remaining);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _idleTimer?.cancel();
    }
  }

  void _markActivity() {
    if (!mounted || _isWarningVisible) return;
    _lastActivityAt = DateTime.now();
    _scheduleIdleTimer(widget.idleTimeout);
  }

  void _scheduleIdleTimer(Duration duration) {
    _idleTimer?.cancel();
    if (_isWarningVisible) return;
    _idleTimer = Timer(duration, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    if (!mounted || _isWarningVisible) return;
    _showExitWarningDialog();
  }

  Future<void> _showExitWarningDialog() async {
    _isWarningVisible = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = AppColor.of(dialogContext);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Inactive Session'),
          content: const Text(
            'No activity detected. Exit the app?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    _isWarningVisible = false;
    if (!mounted) return;

    if (shouldExit == true) {
      _exitApp();
      return;
    }

    _lastActivityAt = DateTime.now();
    _scheduleIdleTimer(widget.idleTimeout);
  }

  void _exitApp() {
    _isWarningVisible = false;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
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
