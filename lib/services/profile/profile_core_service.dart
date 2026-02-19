import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/profile_service.dart';
import 'models/profile_dtos.dart';
import 'models/profile_models.dart';

class ProfileCoreService {
  ProfileCoreService._();

  static final ProfileCoreService I = ProfileCoreService._();

  late final ProfileService _api = ProfileService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<ProfileModel?> getMe() async => _api.getMe();

  Future<ProfileModel> upsertMe(UpsertProfileRequest req) async =>
      _api.upsertMe(req);

  Future<ProfileModel> patchMe(UpsertProfileRequest req) async =>
      _api.patchMe(req);

  Future<bool> deleteMe() async => _api.deleteMe();

  Future<MerchantRequestStatusModel> getMerchantRequestStatus() async =>
      _api.getMerchantRequestStatus();

  Future<MerchantRequestStatusModel> requestMerchantAccess({
    String? note,
  }) async => _api.requestMerchantAccess(note: note);
}
