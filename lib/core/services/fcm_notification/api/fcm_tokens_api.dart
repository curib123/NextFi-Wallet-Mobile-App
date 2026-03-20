import 'api_client.dart';
import '../models/fcm_models.dart';

class FcmTokensApi {
  final ApiClient _api;
  const FcmTokensApi(this._api);

  Future<dynamic> upsert(UpsertFcmTokenRequest req) {
    return _api.post('/fcm-tokens/upsert', req.toJson(), auth: true);
  }

  Future<dynamic> listMine() {
    return _api.get('/fcm-tokens/me', auth: true);
  }

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

  Future<dynamic> deactivateByDeviceId(String deviceId) {
    return _api.delete('/fcm-tokens/device/$deviceId', auth: true);
  }

  Future<dynamic> deactivateByToken(String token) {
    final encoded = Uri.encodeComponent(token);
    return _api.delete('/fcm-tokens/token/$encoded', auth: true);
  }
}
