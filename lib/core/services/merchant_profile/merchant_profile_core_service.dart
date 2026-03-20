import 'dart:async';
import 'dart:io';

import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'api/merchant_profile_service.dart';
import 'models/merchant_profile_dtos.dart';
import 'models/merchant_profile_models.dart';
import 'models/merchant_tier_progress_models.dart';

class MerchantProfileCoreService {
  MerchantProfileCoreService._();

  static final MerchantProfileCoreService I = MerchantProfileCoreService._();
  static final StreamController<void> _changesCtrl =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesCtrl.stream;

  late final MerchantProfileService _api = MerchantProfileService(
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

  Future<MerchantProfileModel?> getMe() async => _api.getMe();

  Future<MerchantTierProgressModel?> getTierProgress() async =>
      _api.getTierProgress();

  Future<MerchantProfileModel> request(
    RequestMerchantProfileRequest req,
  ) async {
    final profile = await _api.request(req);
    _emitChanged();
    return profile;
  }

  Future<MerchantProfileModel> updateMe(
    UpdateMerchantProfileRequest req,
  ) async {
    final profile = await _api.updateMe(req);
    _emitChanged();
    return profile;
  }

  Future<MerchantProfileModel> updateAvailability(
    UpdateMerchantAvailabilityRequest req,
  ) async {
    final profile = await _api.updateAvailability(req);
    _emitChanged();
    return profile;
  }

  Future<MerchantProfileModel> uploadBusinessDocs({
    File? businessDocument,
    File? authorizationLetter,
  }) async {
    final profile = await _api.uploadBusinessDocs(
      businessDocument: businessDocument,
      authorizationLetter: authorizationLetter,
    );
    _emitChanged();
    return profile;
  }

  Future<MerchantProfileModel?> getPublic(String userId) async =>
      _api.getPublic(userId);

  void _emitChanged() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }
}
