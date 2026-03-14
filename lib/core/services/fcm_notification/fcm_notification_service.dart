import 'api/api_client.dart';
import 'api/fcm_tokens_api.dart';
import 'api/notifications_api.dart';

class FcmNotificationService {
  final ApiClient _api;

  late final FcmTokensApi fcmTokens;
  late final NotificationsApi notifications;

  FcmNotificationService({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
  }) : _api = ApiClient(baseUrl: baseUrl, tokenProvider: tokenProvider) {
    fcmTokens = FcmTokensApi(_api);
    notifications = NotificationsApi(_api);
  }

  void dispose() => _api.dispose();
}
