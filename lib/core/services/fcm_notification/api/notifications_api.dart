import 'api_client.dart';
import '../models/fcm_models.dart';

class NotificationsApi {
  final ApiClient _api;
  const NotificationsApi(this._api);

  // POST /notifications/me
  Future<dynamic> sendToMe(SendPushRequest req) {
    return _api.post('/notifications/me', req.toJson(), auth: true);
  }

  // POST /notifications/user
  Future<dynamic> sendToUser(SendPushToUserRequest req) {
    return _api.post('/notifications/user', req.toJson(), auth: true);
  }

  // POST /notifications/token
  Future<dynamic> sendToToken(SendPushToTokenRequest req) {
    return _api.post('/notifications/token', req.toJson(), auth: true);
  }
}
