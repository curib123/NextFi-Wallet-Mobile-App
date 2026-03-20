import 'dart:async';

typedef AppNavigationHandler =
    Future<bool> Function(String route, Map<String, dynamic> payload);

class AppNavigationBridge {
  AppNavigationBridge._();

  static final List<_PendingNavigation> _pending = <_PendingNavigation>[];
  static AppNavigationHandler? _handler;

  static void register(AppNavigationHandler handler) {
    _handler = handler;
    unawaited(_flushPending());
  }

  static void unregister(AppNavigationHandler handler) {
    if (identical(_handler, handler)) {
      _handler = null;
    }
  }

  static Future<void> open(
    String route, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final normalizedRoute = route.trim();
    if (normalizedRoute.isEmpty) return;

    final handler = _handler;
    if (handler == null) {
      _pending.add(
        _PendingNavigation(normalizedRoute, Map<String, dynamic>.from(payload)),
      );
      return;
    }

    final handled = await handler(
      normalizedRoute,
      Map<String, dynamic>.from(payload),
    );
    if (!handled) {
      _pending.add(
        _PendingNavigation(normalizedRoute, Map<String, dynamic>.from(payload)),
      );
    }
  }

  static Future<void> _flushPending() async {
    final handler = _handler;
    if (handler == null || _pending.isEmpty) return;

    final queue = List<_PendingNavigation>.from(_pending);
    _pending.clear();

    for (final item in queue) {
      final handled = await handler(item.route, item.payload);
      if (!handled) {
        _pending.add(item);
        break;
      }
    }
  }
}

class _PendingNavigation {
  const _PendingNavigation(this.route, this.payload);

  final String route;
  final Map<String, dynamic> payload;
}
