import 'dart:async';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/profile_service.dart';
import 'models/profile_dtos.dart';
import 'models/profile_models.dart';

class ProfileCoreService {
  ProfileCoreService._();

  static final ProfileCoreService I = ProfileCoreService._();
  static final StreamController<void> _changesCtrl =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesCtrl.stream;

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

  Future<ProfileModel> upsertMe(UpsertProfileRequest req) async {
    final profile = await _api.upsertMe(req);
    _emitChanged();
    return profile;
  }

  Future<ProfileModel> patchMe(UpsertProfileRequest req) async {
    final profile = await _api.patchMe(req);
    _emitChanged();
    return profile;
  }

  Future<bool> deleteMe() async {
    final ok = await _api.deleteMe();
    if (ok) _emitChanged();
    return ok;
  }

  Future<MerchantRequestStatusModel> getMerchantRequestStatus() async =>
      _api.getMerchantRequestStatus();

  Future<MerchantRequestStatusModel> requestMerchantAccess({
    String? note,
  }) async {
    final status = await _api.requestMerchantAccess(note: note);
    _emitChanged();
    return status;
  }

  void _emitChanged() {
    if (!_changesCtrl.isClosed) {
      _changesCtrl.add(null);
    }
  }
}
