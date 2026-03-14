import 'dart:io';

import 'package:next_fi/core/services/secure_storage/token_storage.dart';

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
    // â”€â”€ Required â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    required String phoneNumber,
    required File selfie,
    required File governmentIdFront,
    required File governmentIdBack,
    // â”€â”€ Identity snapshot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    String? fullLegalName,
    DateTime? dateOfBirth,
    String? nationality,
    String? countryOfResidence,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateOrProvince,
    String? postalCode,
    String? issuingCountry,
    // â”€â”€ Government ID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GovernmentIdType? governmentIdType,
    String? governmentIdNumber,
    DateTime? governmentIdExpiry,
    // â”€â”€ Payment account â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    String? paymentAccountId,
    // â”€â”€ Consent â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    DateTime? consentAcceptedAt,
    String? consentVersion,
  }) async => _api.submit(
    phoneNumber: phoneNumber,
    selfie: selfie,
    governmentIdFront: governmentIdFront,
    governmentIdBack: governmentIdBack,
    fullLegalName: fullLegalName,
    dateOfBirth: dateOfBirth,
    nationality: nationality,
    countryOfResidence: countryOfResidence,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    city: city,
    stateOrProvince: stateOrProvince,
    postalCode: postalCode,
    issuingCountry: issuingCountry,
    governmentIdType: governmentIdType,
    governmentIdNumber: governmentIdNumber,
    governmentIdExpiry: governmentIdExpiry,
    paymentAccountId: paymentAccountId,
    consentAcceptedAt: consentAcceptedAt,
    consentVersion: consentVersion,
  );

  Future<VerificationModel> resubmit({
    File? selfie,
    File? governmentIdFront,
    File? governmentIdBack,
    List<String>? resubmittingFields,
    String? phoneNumber,
    String? fullLegalName,
    DateTime? dateOfBirth,
    String? nationality,
    String? countryOfResidence,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateOrProvince,
    String? postalCode,
    String? issuingCountry,
    GovernmentIdType? governmentIdType,
    String? governmentIdNumber,
    DateTime? governmentIdExpiry,
    String? paymentAccountId,
    DateTime? consentAcceptedAt,
    String? consentVersion,
  }) async => _api.resubmit(
    selfie: selfie,
    governmentIdFront: governmentIdFront,
    governmentIdBack: governmentIdBack,
    resubmittingFields: resubmittingFields,
    phoneNumber: phoneNumber,
    fullLegalName: fullLegalName,
    dateOfBirth: dateOfBirth,
    nationality: nationality,
    countryOfResidence: countryOfResidence,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    city: city,
    stateOrProvince: stateOrProvince,
    postalCode: postalCode,
    issuingCountry: issuingCountry,
    governmentIdType: governmentIdType,
    governmentIdNumber: governmentIdNumber,
    governmentIdExpiry: governmentIdExpiry,
    paymentAccountId: paymentAccountId,
    consentAcceptedAt: consentAcceptedAt,
    consentVersion: consentVersion,
  );
}
