import 'dart:async';
import 'dart:io';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/merchant_profile_service.dart';
import 'models/merchant_profile_dtos.dart';
import 'models/merchant_profile_models.dart';

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

  /// Returns null if the user has not applied to be a merchant yet.
  Future<MerchantProfileModel?> getMe() async => _api.getMe();

  /// Submit or re-submit a merchant application.
  Future<MerchantProfileModel> request(
    RequestMerchantProfileRequest req,
  ) async {
    final profile = await _api.request(req);
    _emitChanged();
    return profile;
  }

  /// Update merchant profile details (APPROVED merchants only).
  Future<MerchantProfileModel> updateMe(
    UpdateMerchantProfileRequest req,
  ) async {
    final profile = await _api.updateMe(req);
    _emitChanged();
    return profile;
  }

  /// Update availability schedule (APPROVED merchants only).
  Future<MerchantProfileModel> updateAvailability(
    UpdateMerchantAvailabilityRequest req,
  ) async {
    final profile = await _api.updateAvailability(req);
    _emitChanged();
    return profile;
  }

  /// Upload business documents. At least one file is required.
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

  /// Fetch the public profile of an approved merchant.
  Future<MerchantProfileModel?> getPublic(String userId) async =>
      _api.getPublic(userId);

  void _emitChanged() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }
}
