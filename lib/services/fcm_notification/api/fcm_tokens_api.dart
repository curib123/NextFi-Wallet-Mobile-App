import 'api_client.dart';
import '../models/fcm_models.dart';

class FcmTokensApi {
  final ApiClient _api;
  const FcmTokensApi(this._api);

  // POST /fcm-tokens/upsert
  Future<dynamic> upsert(UpsertFcmTokenRequest req) {
    return _api.post('/fcm-tokens/upsert', req.toJson(), auth: true);
  }

  // GET /fcm-tokens/me
  Future<dynamic> listMine() {
    return _api.get('/fcm-tokens/me', auth: true);
  }

  // PATCH /fcm-tokens/:id
  Future<dynamic> updateById({
    required String id,
    String? token,
    bool? isActive,
  }) {
    return _api.patch('/fcm-tokens/$id', {
      if (token != null) 'token': token,
      if (isActive != null) 'isActive': isActive,
    }, auth: true);
  }

  // DELETE /fcm-tokens/device/:deviceId
  Future<dynamic> deactivateByDeviceId(String deviceId) {
    return _api.delete('/fcm-tokens/device/$deviceId', auth: true);
  }

  // DELETE /fcm-tokens/token/:token
  Future<dynamic> deactivateByToken(String token) {
    final encoded = Uri.encodeComponent(token);
    return _api.delete('/fcm-tokens/token/$encoded', auth: true);
  }
}
