// flutter_local_notifications: ^20.1.0
//
// ✅ Remove `settings: null` from initialize (NOT a valid param)
// ✅ Remove `id: null` from show (NOT a valid param)
// ✅ If you truly want "no id", you can't — id is REQUIRED by the API.
//    We generate a safe unique id automatically.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LocalNotif {
  LocalNotif._();
  static final LocalNotif I = LocalNotif._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.max,
  );

  @pragma('vm:entry-point')
  static void _localNotifTapBackground(NotificationResponse r) {
    debugPrint('[LOCAL_NOTIF][bg-tap] payload=${r.payload}');
  }

  Future<void> init({void Function(String? payload)? onLocalTap}) async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@drawable/icon');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        debugPrint('[LOCAL_NOTIF] tapped payload=${r.payload}');
        onLocalTap?.call(r.payload);
      },
      onDidReceiveBackgroundNotificationResponse: _localNotifTapBackground,
      settings: initSettings,
    );

    // Android 8+ channel
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);

    // iOS permissions (use IOSFlutterLocalNotificationsPlugin)
    final ios =
    _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _inited = true;
  }

  // Unique id generator (no null id possible)
  int _nextId() =>
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

  Future<void> showFromFcm(RemoteMessage msg) async {
    final n = msg.notification;
    final title = n?.title ?? msg.data['title']?.toString() ?? 'Notification';
    final body = n?.body ?? msg.data['body']?.toString() ?? '';

    // Keep payload simple (route only)
    final payload = msg.data['route']?.toString();

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/icon',
    );


    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: _nextId(), // ✅ REQUIRED
      title: title,
      body:body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
