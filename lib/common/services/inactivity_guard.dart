import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';

class InactivityGuard extends StatefulWidget {
  const InactivityGuard({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 2),
    this.warningDuration = const Duration(seconds: 20),
  });

  final Widget child;
  final Duration idleTimeout;
  final Duration warningDuration;

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  Timer? _warningTimer;
  AppAlertController? _alertController;
  bool _isWarningVisible = false;
  late DateTime _lastActivityAt;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastActivityAt = DateTime.now();
    _secondsLeft = widget.warningDuration.inSeconds;
    _scheduleIdleTimer(widget.idleTimeout);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _warningTimer?.cancel();
    _alertController?.close();
    _alertController = null;
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
    _secondsLeft = widget.warningDuration.inSeconds;
    _alertController?.close();
    _alertController = showAppAlert(
      context,
      type: AppAlertType.warning,
      title: 'Inactive Session',
      subtitle:
          'No activity detected. The app will close in $_secondsLeft seconds.',
      primaryText: 'Cancel',
      onPrimary: _cancelExit,
      barrierDismissible: false,
    );

    _warningTimer?.cancel();
    _warningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isWarningVisible) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        _exitApp();
      } else {
        _secondsLeft -= 1;
        _alertController?.update(
          AppAlertType.warning,
          title: 'Inactive Session',
          subtitle:
              'No activity detected. The app will close in $_secondsLeft seconds.',
          primaryText: 'Cancel',
          onPrimary: _cancelExit,
        );
      }
    });
  }

  void _cancelExit() {
    _warningTimer?.cancel();
    if (!_isWarningVisible) return;

    _isWarningVisible = false;
    _lastActivityAt = DateTime.now();
    _alertController?.close();
    _alertController = null;

    _scheduleIdleTimer(widget.idleTimeout);
  }

  void _exitApp() {
    _warningTimer?.cancel();
    _isWarningVisible = false;
    _alertController?.close();
    _alertController = null;

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
