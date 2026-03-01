import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/services/network_monitor.dart';
import 'package:provider/provider.dart';

class InternetLossGuard extends StatefulWidget {
  const InternetLossGuard({
    super.key,
    required this.child,
    this.warningDuration = const Duration(seconds: 20),
  });

  final Widget child;
  final Duration warningDuration;

  @override
  State<InternetLossGuard> createState() => _InternetLossGuardState();
}

class _InternetLossGuardState extends State<InternetLossGuard> {
  Timer? _warningTimer;
  AppAlertController? _alertController;
  bool _isDialogVisible = false;
  bool _dismissedForCurrentOfflineSession = false;
  bool? _lastIsOnline;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _warningTimer?.cancel();
    _alertController?.close();
    _alertController = null;
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnline) {
    final previous = _lastIsOnline;
    _lastIsOnline = isOnline;

    if (isOnline) {
      _dismissedForCurrentOfflineSession = false;
      _cancelOfflineWarning();
      return;
    }

    if (previous == false) return;
    if (_dismissedForCurrentOfflineSession) return;
    _showOfflineWarningDialog();
  }

  void _showOfflineWarningDialog() {
    if (!mounted || _isDialogVisible) return;

    _isDialogVisible = true;
    _secondsLeft = widget.warningDuration.inSeconds;
    _alertController?.close();
    _alertController = showAppAlert(
      context,
      type: AppAlertType.warning,
      title: 'No Internet Connection',
      subtitle:
          'No internet detected. The app will close in $_secondsLeft seconds.',
      primaryText: 'Cancel',
      onPrimary: _cancelByUser,
      barrierDismissible: false,
    );

    _warningTimer?.cancel();
    _warningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isDialogVisible) {
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
          title: 'No Internet Connection',
          subtitle:
              'No internet detected. The app will close in $_secondsLeft seconds.',
          primaryText: 'Cancel',
          onPrimary: _cancelByUser,
        );
      }
    });
  }

  void _cancelByUser() {
    _dismissedForCurrentOfflineSession = true;
    _cancelOfflineWarning();
  }

  void _cancelOfflineWarning() {
    _warningTimer?.cancel();
    _isDialogVisible = false;
    _alertController?.close();
    _alertController = null;
  }

  void _exitApp() {
    _warningTimer?.cancel();
    _isDialogVisible = false;
    _alertController?.close();
    _alertController = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkMonitor>(
      builder: (_, monitor, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleConnectivityChange(monitor.isOnline);
          }
        });
        return widget.child;
      },
    );
  }
}
