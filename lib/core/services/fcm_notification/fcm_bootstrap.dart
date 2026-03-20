import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:next_fi/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmBootstrap {
  static final FirebaseMessaging _msg = FirebaseMessaging.instance;

  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _msg.requestPermission(alert: true, badge: true, sound: true);

    await _msg.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<String?> getToken() async {
    return _msg.getToken();
  }

  static Future<void> bindListeners({
    required void Function(RemoteMessage msg) onForeground,
    required void Function(RemoteMessage msg) onOpenedFromBackground,
    required void Function(RemoteMessage msg) onOpenedFromTerminated,
  }) async {
    FirebaseMessaging.onMessage.listen(onForeground);

    FirebaseMessaging.onMessageOpenedApp.listen(onOpenedFromBackground);

    final initial = await _msg.getInitialMessage();
    if (initial != null) {
      onOpenedFromTerminated(initial);
    }
  }
}
