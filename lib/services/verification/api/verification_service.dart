import 'dart:io';

import 'package:http/http.dart' as http;

import '../helpers/verification_exceptions.dart';
import '../helpers/verification_helpers.dart';
import '../models/verification_models.dart';
import 'verification_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class VerificationService {
  VerificationService({required this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
  final http.Client _client;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _tokenOrThrow() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }
    return token;
  }

  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;
    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;
      final wrappedData = data['data'];
      final wrappedVerification = data['verification'];
      if (wrappedData is Map<String, dynamic>) return wrappedData;
      if (wrappedVerification is Map<String, dynamic>)
        return wrappedVerification;
      if (data.length == 1 &&
          (data.containsKey('data') || data.containsKey('verification')) &&
          wrappedData == null &&
          wrappedVerification == null) {
        return null;
      }
      return data;
    }
    return null;
  }

  Future<VerificationModel> getMe() async {
    try {
      final res = await _client.get(
        VerificationHttp.uri(VerificationEndpoints.me()),
        headers: await _headers(),
      );

      VerificationHttp.ensureOk(res);
      final data = VerificationHttp.decodeJson<dynamic>(res);
      final map = _extractMap(data);

      if (map != null) {
        return VerificationModel.fromJson(map);
      }
    } on ApiException catch (e) {
      // First-time users may not have a verification row yet.
      if (e.statusCode != 404) rethrow;
    }

    // First-time fallback: treat missing/empty response as BASIC.
    return const VerificationModel(
      id: '',
      userId: '',
      status: TrustStatus.basic,
    );
  }

  Future<VerificationModel> submit({
    // ── Required ──────────────────────────────────────────
    required String phoneNumber,
    required File selfie,
    required File governmentIdFront,
    required File governmentIdBack,
    // ── Identity snapshot ─────────────────────────────────
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
    // ── Government ID ─────────────────────────────────────
    GovernmentIdType? governmentIdType,
    String? governmentIdNumber,
    DateTime? governmentIdExpiry,
    // ── Payment account ───────────────────────────────────
    String? paymentAccountId,
    // ── Consent ───────────────────────────────────────────
    DateTime? consentAcceptedAt,
    String? consentVersion,
  }) async {
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      throw ApiException(400, 'Phone number is required.');
    }

    void ensureSupportedImage(File file, String label) {
      final normalized = file.path.trim().toLowerCase();
      final dot = normalized.lastIndexOf('.');
      final ext = dot >= 0 ? normalized.substring(dot + 1) : '';
      if (!_allowedExtensions.contains(ext)) {
        throw ApiException(
          400,
          '$label must be an image file (JPG, JPEG, PNG, WEBP).',
        );
      }
    }

    ensureSupportedImage(selfie, 'Selfie');
    ensureSupportedImage(governmentIdFront, 'Government ID front');
    ensureSupportedImage(governmentIdBack, 'Government ID back');

    final token = await _tokenOrThrow();

    final req = http.MultipartRequest(
      'POST',
      VerificationHttp.uri(VerificationEndpoints.submit()),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
    // ── Required fields ───────────────────────────────
      ..fields['phoneNumber'] = normalizedPhone
      ..files.add(await http.MultipartFile.fromPath('selfie', selfie.path))
      ..files.add(
        await http.MultipartFile.fromPath(
          'governmentIdFront',
          governmentIdFront.path,
        ),
      )
      ..files.add(
        await http.MultipartFile.fromPath(
          'governmentIdBack',
          governmentIdBack.path,
        ),
      );

    // ── Identity snapshot ─────────────────────────────────
    _addField(req, 'fullLegalName', fullLegalName);
    _addField(
      req,
      'dateOfBirth',
      dateOfBirth != null
          ? '${dateOfBirth.year.toString().padLeft(4, '0')}'
          '-${dateOfBirth.month.toString().padLeft(2, '0')}'
          '-${dateOfBirth.day.toString().padLeft(2, '0')}'
          : null,
    );
    _addField(req, 'nationality', nationality);
    _addField(req, 'countryOfResidence', countryOfResidence);
    _addField(req, 'addressLine1', addressLine1);
    _addField(req, 'addressLine2', addressLine2);
    _addField(req, 'city', city);
    _addField(req, 'stateOrProvince', stateOrProvince);
    _addField(req, 'postalCode', postalCode);
    _addField(req, 'issuingCountry', issuingCountry);

    // ── Government ID ─────────────────────────────────────
    _addField(req, 'governmentIdType', governmentIdType?.apiValue);
    _addField(req, 'governmentIdNumber', governmentIdNumber);
    _addField(
      req,
      'governmentIdExpiry',
      governmentIdExpiry != null
          ? '${governmentIdExpiry.year.toString().padLeft(4, '0')}'
          '-${governmentIdExpiry.month.toString().padLeft(2, '0')}'
          '-${governmentIdExpiry.day.toString().padLeft(2, '0')}'
          : null,
    );

    // ── Payment account ───────────────────────────────────
    _addField(req, 'paymentAccountId', paymentAccountId);

    // ── Consent ───────────────────────────────────────────
    _addField(
      req,
      'consentAcceptedAt',
      consentAcceptedAt?.toUtc().toIso8601String(),
    );
    _addField(req, 'consentVersion', consentVersion);

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    VerificationHttp.ensureOk(res);
    final data = VerificationHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data);

    if (map != null) {
      return VerificationModel.fromJson(map);
    }

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /verification/submit',
      body: res.body,
    );
  }

  /// Adds a field to a [MultipartRequest] only when [value] is non-null
  /// and non-blank, keeping the request clean.
  void _addField(http.MultipartRequest req, String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      req.fields[key] = trimmed;
    }
  }
}