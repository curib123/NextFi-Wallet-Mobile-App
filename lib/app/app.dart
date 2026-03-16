// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Flutter SDK Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
import 'package:flutter/material.dart';

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ 3rd-party packages Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/app/config/app_config.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/settings/presentation/viewmodels/settings_vm.dart';
import 'package:next_fi/firebase_options.dart';
import 'package:next_fi/app/theme/app_theme.dart';
import 'package:next_fi/core/services/device_meta/device_meta_service.dart';
import 'package:next_fi/core/services/fcm_notification/fcm_notification_core.dart';
import 'package:next_fi/core/services/fcm_notification/fcm_bootstrap.dart';
import 'package:next_fi/core/services/local_notif/local_notification_service.dart';

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ App core Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
import 'package:next_fi/app/app_shell.dart';
import 'package:next_fi/core/services/internet_loss_guard.dart';
import 'package:next_fi/core/services/inactivity_guard.dart';
import 'package:next_fi/core/widgets/network_status_overlay.dart';
import 'package:next_fi/core/widgets/modal/global_announcement_host.dart';

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Services Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ View Models Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Theme persistence Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
const String _kThemePrefKey = 'pref.theme_mode.v1';
const String _kThemeStylePrefKey = 'pref.theme_style_index.v1';
const FlutterSecureStorage _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

final ValueNotifier<ThemeMode> _themeModeVN = ValueNotifier(ThemeMode.system);
final ValueNotifier<int> _themeStyleVN = ValueNotifier(2);

Future<void> _loadInitialThemeMode() async {
  final raw = await _secure.read(key: _kThemePrefKey) ?? 'system';
  final mode = switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  _themeModeVN.value = mode;
}

Future<void> _loadInitialThemeStyle() async {
  final raw = await _secure.read(key: _kThemeStylePrefKey);
  final parsed = int.tryParse(raw ?? '');
  _themeStyleVN.value = AppColor.normalizeThemeStyleIndex(parsed ?? 2);
}

Future<void> _setThemeStyle(int styleIndex) async {
  final normalized = AppColor.normalizeThemeStyleIndex(styleIndex);
  _themeStyleVN.value = normalized;
  await _secure.write(key: _kThemeStylePrefKey, value: normalized.toString());
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Currency glyph fallback Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// If Sora can't render Ã¢â€šÂ±/Ã¢â€šÂ¹/Ã Â¸Â¿/Ã¯Â·Â¼ etc, Flutter will fallback to these fonts.
// IMPORTANT: Font family names MUST match exactly.
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ FCM background handler Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM][bg] ${message.messageId} data=${message.data}');
  // System notification is shown automatically by backend config (no need to call LocalNotif here)
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.bootstrap();
  await _loadInitialThemeMode();
  await _loadInitialThemeStyle();

  ThemeBridge.apply = (mode) async {
    _themeModeVN.value = mode;
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _secure.write(key: _kThemePrefKey, value: raw);
  };
  ThemeStyleBridge.apply = _setThemeStyle;

  // Ã¢Å“â€¦ Use FcmBootstrap for clean initialization
  await FcmBootstrap.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(ProviderScope(child: Phoenix(child: const MyApp())));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const TextScaler _kClampedTextScaler = TextScaler.linear(1.0);

  bool get _isRunningWidgetTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    if (_isRunningWidgetTest) return;
    _bindFcm();
  }

  Future<void> _bindFcm() async {
    if (_isRunningWidgetTest) return;

    // Ã¢Å“â€¦ Initialize local notifications for foreground display
    await LocalNotif.I.init(
      onLocalTap: (payload) {
        if (payload != null && payload.isNotEmpty) {
          debugPrint('[LOCAL_NOTIF] Navigate to: $payload');
          // Navigator.of(context).pushNamed(payload);
        }
      },
    );

    // Ã¢Å“â€¦ Get device meta and token
    final token = await FcmBootstrap.getToken();
    final deviceMeta = await DeviceMetaService.instance.getMeta();

    debugPrint('[FCM] token=$token');
    debugPrint(
      '[FCM] deviceId=${deviceMeta.deviceId} platform=${deviceMeta.platform} appVersion=${deviceMeta.appVersion}',
    );

    // Ã¢Å“â€¦ Register token with backend
    if (token != null) {
      try {
        await FcmNotificationCore().upsertDeviceToken(
          fcmToken: token,
          deviceId: deviceMeta.deviceId,
          platform: deviceMeta.platform,
          appVersion: deviceMeta.appVersion,
        );
      } catch (e) {
        debugPrint('[FCM] upsert skipped (likely not logged in yet): $e');
      }
    }

    // Ã¢Å“â€¦ Auto update when token changes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed=$newToken');
      try {
        await FcmNotificationCore().upsertDeviceToken(
          fcmToken: newToken,
          deviceId: deviceMeta.deviceId,
          platform: deviceMeta.platform,
          appVersion: deviceMeta.appVersion,
        );
      } catch (e) {
        debugPrint('[FCM] upsert on refresh failed (likely logged out): $e');
      }
    });

    // Ã¢Å“â€¦ Use FcmBootstrap.bindListeners for clean setup
    await FcmBootstrap.bindListeners(
      onForeground: (RemoteMessage msg) async {
        debugPrint(
          '[FCM][onMessage] ${msg.notification?.title} | ${msg.notification?.body}',
        );
        debugPrint('[FCM][data] ${msg.data}');
        // Show notification in foreground using LocalNotif
        await LocalNotif.I.showFromFcm(msg);
      },
      onOpenedFromBackground: (RemoteMessage msg) {
        debugPrint('[FCM][openedApp] data=${msg.data}');
        _handlePushTap(msg);
      },
      onOpenedFromTerminated: (RemoteMessage msg) {
        debugPrint('[FCM][initialMessage] data=${msg.data}');
        _handlePushTap(msg);
      },
    );
  }

  void _handlePushTap(RemoteMessage msg) {
    final route = msg.data['route'];
    if (route is String && route.isNotEmpty) {
      debugPrint('[FCM] Navigate to: $route');
      // Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeVN,
      builder: (_, mode, __) {
        return ValueListenableBuilder<int>(
          valueListenable: _themeStyleVN,
          builder: (_, styleIndex, __) {
            return MaterialApp(
              title: 'NextFi Wallet',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: AppTheme.light(styleIndex),
              darkTheme: AppTheme.dark(styleIndex),
              home: const Home(),
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(textScaler: _kClampedTextScaler),
                  child: NetworkStatusOverlay(
                    child: GlobalAnnouncementHost(
                      child: InactivityGuard(
                        child: InternetLossGuard(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
