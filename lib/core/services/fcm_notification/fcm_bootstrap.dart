import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:next_fi/firebase_options.dart';

/// IMPORTANT: must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can log or update local state here.
  // NOTE: Showing a notification UI in background usually needs flutter_local_notifications.
}

class FcmBootstrap {
  static final FirebaseMessaging _msg = FirebaseMessaging.instance;

  /// Call once in main() BEFORE runApp()
  static Future<void> init() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Background/terminated handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // iOS + Android 13+: request permission (Android 12 and below returns granted)
    await _msg.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Optional but common: show heads-up notifications when app is foreground
    await _msg.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Get FCM token for this device
  static Future<String?> getToken() async {
    return _msg.getToken();
  }

  /// Listen to notifications:
  /// - foreground: onMessage
  /// - tapped from background: onMessageOpenedApp
  /// - tapped from terminated: getInitialMessage
  static Future<void> bindListeners({
    required void Function(RemoteMessage msg) onForeground,
    required void Function(RemoteMessage msg) onOpenedFromBackground,
    required void Function(RemoteMessage msg) onOpenedFromTerminated,
  }) async {
    // Foreground message
    FirebaseMessaging.onMessage.listen(onForeground);

    // App opened from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen(onOpenedFromBackground);

    // App opened from terminated by tapping notification
    final initial = await _msg.getInitialMessage();
    if (initial != null) {
      onOpenedFromTerminated(initial);
    }
  }
}
