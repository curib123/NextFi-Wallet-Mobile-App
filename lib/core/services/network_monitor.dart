import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkMonitor extends ChangeNotifier {
  NetworkMonitor() {
    _init();
  }

  static const Duration _probeTimeout = Duration(seconds: 3);
  static const Duration _reconnectedBannerDuration = Duration(seconds: 3);
  static const Duration _periodicProbeInterval = Duration(seconds: 12);

  static final List<Uri> _probeUris = <Uri>[
    Uri.parse('https://clients3.google.com/generate_204'),
    Uri.parse('https://www.gstatic.com/generate_204'),
    Uri.parse('https://cloudflare.com/cdn-cgi/trace'),
  ];

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _reconnectedTimer;
  Timer? _periodicProbeTimer;

  bool _isOnline = true;
  bool _justReconnected = false;
  bool _isDisposed = false;
  bool _isProbing = false;

  bool get isOnline => _isOnline;
  bool get justReconnected => _justReconnected;

  Future<void> _init() async {
    await _refreshStatus(notify: false);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) async {
      await _refreshStatus();
    });

    _periodicProbeTimer = Timer.periodic(_periodicProbeInterval, (_) async {
      await _refreshStatus();
    });
  }

  Future<void> _refreshStatus({bool notify = true}) async {
    if (_isDisposed || _isProbing) return;

    _isProbing = true;
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      final bool hasTransport = _hasTransport(results);
      final bool online = hasTransport && await _hasRealInternetAccess();

      _setOnlineState(online, notify: notify);
    } catch (_) {
      _setOnlineState(false, notify: notify);
    } finally {
      _isProbing = false;
    }
  }

  bool _hasTransport(List<ConnectivityResult> results) {
    return results.any((ConnectivityResult result) {
      return result != ConnectivityResult.none;
    });
  }

  Future<bool> _hasRealInternetAccess() async {
    for (final Uri uri in _probeUris) {
      final bool reachable = await _probeUri(uri);
      if (reachable) return true;
    }
    return false;
  }

  Future<bool> _probeUri(Uri uri) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = _probeTimeout
        ..idleTimeout = _probeTimeout;

      final HttpClientRequest request = await client
          .headUrl(uri)
          .timeout(_probeTimeout);
      request.followRedirects = false;

      final HttpClientResponse response = await request.close().timeout(
        _probeTimeout,
      );

      await response.drain<void>();

      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  void _setOnlineState(bool online, {required bool notify}) {
    if (online == _isOnline) {
      if (notify) notifyListeners();
      return;
    }

    final bool wasOffline = !_isOnline;
    _isOnline = online;

    if (wasOffline && online) {
      _justReconnected = true;
      _reconnectedTimer?.cancel();
      _reconnectedTimer = Timer(_reconnectedBannerDuration, () {
        if (_isDisposed) return;
        _justReconnected = false;
        notifyListeners();
      });
    } else {
      _justReconnected = false;
      _reconnectedTimer?.cancel();
    }

    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySub?.cancel();
    _reconnectedTimer?.cancel();
    _periodicProbeTimer?.cancel();
    super.dispose();
  }
}
