// lib/services/fcm_notification/fcm_notification_core.dart
//
// Core / single place to access FCM Tokens + Notifications APIs.
// Uses:
//   - _baseUrl = cetralized_baseUrl
//   - TokenStorage (FlutterSecureStorage)
//
// Usage:
//   final fcmCore = FcmNotificationCore();
//   await fcmCore.upsertDeviceToken(...);
//   await fcmCore.sendPushToMe(...);
//   await fcmCore.sendPushToUser(...);
//   await fcmCore.logoutDeactivateDevice(...);

import 'package:next_fi/services/fcm_notification/fcm_notification_service.dart';
import 'package:next_fi/services/fcm_notification/models/fcm_models.dart';
import 'package:next_fi/services/oath2.0/token_storage.dart';

import '../base_url/base_url.dart' show cetralized_baseUrl;

class FcmNotificationCore {
  static const String _baseUrl = cetralized_baseUrl;

  final TokenStorage _tokenStorage;
  late final FcmNotificationService svc;

  FcmNotificationCore({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage() {
    svc = FcmNotificationService(
      baseUrl: _baseUrl,
      tokenProvider: () async => await _tokenStorage.accessToken,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Convenience helpers (UI-friendly)
  // ─────────────────────────────────────────────────────────────

  /// Save/update this device’s FCM token to backend (JWT required).
  Future<dynamic> upsertDeviceToken({
    required String fcmToken,
    required String deviceId,
    String platform = 'android', // set 'ios' on iOS
    String? appVersion,
  }) {
    return svc.fcmTokens.upsert(
      UpsertFcmTokenRequest(
        token: fcmToken,
        deviceId: deviceId,
        platform: platform,
        appVersion: appVersion,
      ),
    );
  }

  /// Send push to the currently logged-in user (JWT required).
  Future<dynamic> sendPushToMe({
    required String title,
    required String body,
    Map<String, String>? data,
  }) {
    return svc.notifications.sendToMe(
      SendPushRequest(
        title: title,
        body: body,
        data: data ,
      ),
    );
  }




  /// Logout helper: deactivate token(s) for this device (JWT required).
  Future<dynamic> logoutDeactivateDevice(String deviceId) {
    return svc.fcmTokens.deactivateByDeviceId(deviceId);
  }

  /// Optional: free http client.
  void dispose() => svc.dispose();
}
