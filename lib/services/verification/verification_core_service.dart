import 'dart:io';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/verification_service.dart';
import 'models/verification_models.dart';

class VerificationCoreService {
  VerificationCoreService._();

  static final VerificationCoreService I = VerificationCoreService._();

  late final VerificationService _api = VerificationService(
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

  Future<VerificationModel> getMe() async => _api.getMe();

  Future<VerificationModel> submit({
    required String phoneNumber,
    required File selfie,
    required File governmentIdFront,
    required File governmentIdBack,
    String? paymentAccountId,
  }) async => _api.submit(
    phoneNumber: phoneNumber,
    selfie: selfie,
    governmentIdFront: governmentIdFront,
    governmentIdBack: governmentIdBack,
    paymentAccountId: paymentAccountId,
  );
}
