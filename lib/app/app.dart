import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/app/config/app_config.dart';
import 'package:next_fi/app/navigation/app_navigation_bridge.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/settings/presentation/viewmodels/settings_vm.dart';
import 'package:next_fi/firebase_options.dart';
import 'package:next_fi/app/theme/app_theme.dart';
import 'package:next_fi/core/services/device_meta/device_meta_service.dart';
import 'package:next_fi/core/services/fcm_notification/fcm_notification_core.dart';
import 'package:next_fi/core/services/fcm_notification/fcm_bootstrap.dart';
import 'package:next_fi/core/services/local_notif/local_notification_service.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'package:next_fi/app/app_shell.dart';
import 'package:next_fi/core/services/internet_loss_guard.dart';
import 'package:next_fi/core/services/inactivity_guard.dart';
import 'package:next_fi/core/widgets/network_status_overlay.dart';
import 'package:next_fi/core/widgets/modal/global_announcement_host.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM][bg] ${message.messageId} data=${message.data}');
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
  final TokenStorage _tokenStorage = TokenStorage();

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

    await LocalNotif.I.init(
      onLocalTap: (payload) {
        if (payload != null && payload.isNotEmpty) {
          debugPrint('[LOCAL_NOTIF] Navigate to: $payload');
          unawaited(AppNavigationBridge.open(payload));
        }
      },
    );

    final token = await FcmBootstrap.getToken();
    final deviceMeta = await DeviceMetaService.instance.getMeta();

    debugPrint('[FCM] token=$token');
    debugPrint(
      '[FCM] deviceId=${deviceMeta.deviceId} platform=${deviceMeta.platform} appVersion=${deviceMeta.appVersion}',
    );

    if (token != null) {
      try {
        final accessToken = await _tokenStorage.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          debugPrint('[FCM] upsert skipped: no access token yet');
        } else {
          await FcmNotificationCore().upsertDeviceToken(
            fcmToken: token,
            deviceId: deviceMeta.deviceId,
            platform: deviceMeta.platform,
            appVersion: deviceMeta.appVersion,
          );
        }
      } catch (e) {
        debugPrint('[FCM] upsert skipped (likely not logged in yet): $e');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed=$newToken');
      try {
        final accessToken = await _tokenStorage.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          debugPrint('[FCM] refresh upsert skipped: no access token yet');
          return;
        }

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

    await FcmBootstrap.bindListeners(
      onForeground: (RemoteMessage msg) async {
        debugPrint(
          '[FCM][onMessage] ${msg.notification?.title} | ${msg.notification?.body}',
        );
        debugPrint('[FCM][data] ${msg.data}');
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
      unawaited(
        AppNavigationBridge.open(
          route,
          payload: Map<String, dynamic>.from(msg.data),
        ),
      );
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
                final boundedScaler = mq.textScaler.clamp(
                  minScaleFactor: 0.92,
                  maxScaleFactor: 1.12,
                );
                return MediaQuery(
                  data: mq.copyWith(textScaler: boundedScaler),
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
