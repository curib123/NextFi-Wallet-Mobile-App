import 'package:next_fi/core/services/fcm_notification/fcm_notification_service.dart';
import 'package:next_fi/core/services/fcm_notification/models/fcm_models.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import '../base_url/base_url.dart' show centralizedBaseUrl;

class FcmNotificationCore {
  static String get _baseUrl => centralizedBaseUrl;

  final TokenStorage _tokenStorage;
  late final FcmNotificationService svc;

  FcmNotificationCore({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage() {
    svc = FcmNotificationService(
      baseUrl: _baseUrl,
      tokenProvider: () async => await _tokenStorage.accessToken,
    );
  }

  Future<dynamic> upsertDeviceToken({
    required String fcmToken,
    required String deviceId,
    String platform = 'android',
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

  Future<dynamic> sendPushToMe({
    required String title,
    required String body,
    Map<String, String>? data,
  }) {
    return svc.notifications.sendToMe(
      SendPushRequest(title: title, body: body, data: data),
    );
  }

  Future<dynamic> logoutDeactivateDevice(String deviceId) {
    return svc.fcmTokens.deactivateByDeviceId(deviceId);
  }

  void dispose() => svc.dispose();
}
