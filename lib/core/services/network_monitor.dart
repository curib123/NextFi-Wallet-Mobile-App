import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors device network connectivity and exposes reactive state.
///
/// - [isOnline] — true when any non-none connection is detected.
/// - [justReconnected] — briefly true after transitioning offline → online.
class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _isOnline = true;
  bool _justReconnected = false;
  Timer? _reconnectedTimer;

  bool get isOnline => _isOnline;
  bool get justReconnected => _justReconnected;

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _hasConnection(results);
    } catch (_) {
      _isOnline = true; // assume online on error
    }

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online == _isOnline) return;

      final wasOffline = !_isOnline;
      _isOnline = online;

      if (wasOffline && online) {
        // Transitioned offline → online: show "reconnected" briefly
        _justReconnected = true;
        _reconnectedTimer?.cancel();
        _reconnectedTimer = Timer(const Duration(seconds: 3), () {
          _justReconnected = false;
          notifyListeners();
        });
      } else {
        _justReconnected = false;
        _reconnectedTimer?.cancel();
      }

      notifyListeners();
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reconnectedTimer?.cancel();
    super.dispose();
  }
}
