// ignore_for_file: invalid_annotation_target

enum TrustStatus {
  basic,
  reviewing,
  ready,
  suspended,
  unknown;

  static TrustStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'BASIC':
        return TrustStatus.basic;
      case 'REVIEWING':
        return TrustStatus.reviewing;
      case 'READY':
        return TrustStatus.ready;
      case 'SUSPENDED':
        return TrustStatus.suspended;
      default:
        return TrustStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case TrustStatus.basic:
        return 'BASIC';
      case TrustStatus.reviewing:
        return 'REVIEWING';
      case TrustStatus.ready:
        return 'READY';
      case TrustStatus.suspended:
        return 'SUSPENDED';
      case TrustStatus.unknown:
        return 'UNKNOWN';
    }
  }
}

enum GovernmentIdType {
  passport,
  driversLicense,
  nationalId,
  other,
  unknown;

  static GovernmentIdType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PASSPORT':
        return GovernmentIdType.passport;
      case 'DRIVERS_LICENSE':
        return GovernmentIdType.driversLicense;
      case 'NATIONAL_ID':
        return GovernmentIdType.nationalId;
      case 'OTHER':
        return GovernmentIdType.other;
      default:
        return GovernmentIdType.unknown;
    }
  }

  /// API value sent to the server.
  String get apiValue {
    switch (this) {
      case GovernmentIdType.passport:
        return 'PASSPORT';
      case GovernmentIdType.driversLicense:
        return 'DRIVERS_LICENSE';
      case GovernmentIdType.nationalId:
        return 'NATIONAL_ID';
      case GovernmentIdType.other:
        return 'OTHER';
      case GovernmentIdType.unknown:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case GovernmentIdType.passport:
        return 'Passport';
      case GovernmentIdType.driversLicense:
        return "Driver's License";
      case GovernmentIdType.nationalId:
        return 'National ID';
      case GovernmentIdType.other:
        return 'Other';
      case GovernmentIdType.unknown:
        return 'Unknown';
    }
  }
}

class VerificationResubmissionGuide {
  const VerificationResubmissionGuide({
    this.reason,
    this.fields = const [],
    this.updatedAt,
  });

  final String? reason;
  final List<String> fields;
  final DateTime? updatedAt;

  factory VerificationResubmissionGuide.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final rawFields = json['fields'] ?? json['resubmissionFields'];
    final fields = rawFields is List
        ? rawFields
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];

    final reason = (json['reason'] ?? json['message'] ?? '').toString().trim();

    return VerificationResubmissionGuide(
      reason: reason.isEmpty ? null : reason,
      fields: fields,
      updatedAt: parseDate(json['updatedAt'] ?? json['createdAt']),
    );
  }
}

class VerificationReviewLog {
  const VerificationReviewLog({
    this.id,
    this.action,
    this.actorType,
    this.actorId,
    this.reason,
    this.resubmissionFields = const [],
    this.createdAt,
  });

  final String? id;
  final String? action;
  final String? actorType;
  final String? actorId;
  final String? reason;
  final List<String> resubmissionFields;
  final DateTime? createdAt;

  factory VerificationReviewLog.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final rawFields = json['resubmissionFields'] ?? json['fields'];
    final fields = rawFields is List
        ? rawFields
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];

    final reason = (json['reason'] ?? json['description'] ?? '')
        .toString()
        .trim();

    return VerificationReviewLog(
      id: (json['id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['id'] ?? '').toString().trim(),
      action: (json['action'] ?? '').toString().trim().isEmpty
          ? null
          : (json['action'] ?? '').toString().trim(),
      actorType:
          (json['actorType'] ?? json['source'] ?? '').toString().trim().isEmpty
          ? null
          : (json['actorType'] ?? json['source'] ?? '').toString().trim(),
      actorId: (json['actorId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['actorId'] ?? '').toString().trim(),
      reason: reason.isEmpty ? null : reason,
      resubmissionFields: fields,
      createdAt: parseDate(json['createdAt']),
    );
  }
}

class VerificationModel {
  const VerificationModel({
    required this.id,
    required this.userId,
    required this.status,
    // ── Contact ──────────────────────────────────────
    this.phoneNumber,
    // ── Identity snapshot ────────────────────────────
    this.fullLegalName,
    this.dateOfBirth,
    this.nationality,
    this.countryOfResidence,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.stateOrProvince,
    this.postalCode,
    this.issuingCountry,
    // ── Government ID ────────────────────────────────
    this.governmentIdType,
    this.governmentIdNumber,
    this.governmentIdExpiry,
    // ── Document URLs ────────────────────────────────
    this.selfieUrl,
    this.governmentIdFrontUrl,
    this.governmentIdBackUrl,
    // ── Verification scoring ─────────────────────────
    this.liveCapture,
    this.faceMatchScore,
    this.livenessScore,
    this.riskScore,
    this.manualReviewRequired = false,
    // ── Payment account ──────────────────────────────
    this.paymentAccountId,
    // ── Review lifecycle ─────────────────────────────
    this.submittedAt,
    this.lastResubmittedAt,
    this.reviewedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectReason,
    // ── Suspension ───────────────────────────────────
    this.suspendedAt,
    this.suspendReason,
    // ── Consent ──────────────────────────────────────
    this.consentAcceptedAt,
    this.consentVersion,
    // ── Audit ────────────────────────────────────────
    this.submittedIp,
    // ── Timestamps ───────────────────────────────────
    this.createdAt,
    this.updatedAt,
    this.resubmissionGuide,
    this.reviewLogs = const [],
  });

  final String id;
  final String userId;
  final TrustStatus status;

  // ── Contact ──────────────────────────────────────────────
  final String? phoneNumber;

  // ── Identity snapshot ────────────────────────────────────
  final String? fullLegalName;
  final DateTime? dateOfBirth;
  final String? nationality;
  final String? countryOfResidence;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? stateOrProvince;
  final String? postalCode;
  final String? issuingCountry;

  // ── Government ID ────────────────────────────────────────
  final GovernmentIdType? governmentIdType;
  final String? governmentIdNumber;
  final DateTime? governmentIdExpiry;

  // ── Document URLs ────────────────────────────────────────
  final String? selfieUrl;
  final String? governmentIdFrontUrl;
  final String? governmentIdBackUrl;

  // ── Verification scoring ─────────────────────────────────
  final bool? liveCapture;
  final double? faceMatchScore;
  final double? livenessScore;
  final double? riskScore;
  final bool manualReviewRequired;

  // ── Payment account ──────────────────────────────────────
  final String? paymentAccountId;

  // ── Review lifecycle ─────────────────────────────────────
  final DateTime? submittedAt;
  final DateTime? lastResubmittedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectReason;

  // ── Suspension ───────────────────────────────────────────
  final DateTime? suspendedAt;
  final String? suspendReason;

  // ── Consent ──────────────────────────────────────────────
  final DateTime? consentAcceptedAt;
  final String? consentVersion;

  // ── Audit ────────────────────────────────────────────────
  final String? submittedIp;

  // ── Timestamps ───────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VerificationResubmissionGuide? resubmissionGuide;
  final List<VerificationReviewLog> reviewLogs;

  // ── Derived helpers ──────────────────────────────────────

  /// True once all three document images and phone number have been uploaded.
  bool get hasSubmittedRequiredDocuments {
    bool text(String? v) => v != null && v.trim().isNotEmpty;
    return text(selfieUrl) &&
        text(governmentIdFrontUrl) &&
        text(governmentIdBackUrl) &&
        text(phoneNumber);
  }

  /// True if the identity snapshot is at least partially filled.
  bool get hasIdentitySnapshot {
    bool text(String? v) => v != null && v.trim().isNotEmpty;
    return text(fullLegalName) || dateOfBirth != null || text(nationality);
  }

  /// True if government ID details have been provided.
  bool get hasGovernmentIdDetails {
    bool text(String? v) => v != null && v.trim().isNotEmpty;
    return governmentIdType != null ||
        text(governmentIdNumber) ||
        governmentIdExpiry != null;
  }

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v as String);
      } catch (_) {
        return null;
      }
    }

    return VerificationModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      status: TrustStatus.fromString(json['status'] as String?),
      phoneNumber: json['phoneNumber'] as String?,
      fullLegalName: json['fullLegalName'] as String?,
      dateOfBirth: parseDate(json['dateOfBirth']),
      nationality: json['nationality'] as String?,
      countryOfResidence: json['countryOfResidence'] as String?,
      addressLine1: json['addressLine1'] as String?,
      addressLine2: json['addressLine2'] as String?,
      city: json['city'] as String?,
      stateOrProvince: json['stateOrProvince'] as String?,
      postalCode: json['postalCode'] as String?,
      issuingCountry: json['issuingCountry'] as String?,
      governmentIdType: GovernmentIdType.fromString(
        json['governmentIdType'] as String?,
      ),
      governmentIdNumber: json['governmentIdNumber'] as String?,
      governmentIdExpiry: parseDate(json['governmentIdExpiry']),
      selfieUrl: json['selfieUrl'] as String?,
      governmentIdFrontUrl: json['governmentIdFrontUrl'] as String?,
      governmentIdBackUrl: json['governmentIdBackUrl'] as String?,
      liveCapture: json['liveCapture'] as bool?,
      faceMatchScore: (json['faceMatchScore'] as num?)?.toDouble(),
      livenessScore: (json['livenessScore'] as num?)?.toDouble(),
      riskScore: (json['riskScore'] as num?)?.toDouble(),
      manualReviewRequired: (json['manualReviewRequired'] as bool?) ?? false,
      paymentAccountId: json['paymentAccountId'] as String?,
      submittedAt: parseDate(json['submittedAt']),
      lastResubmittedAt: parseDate(json['lastResubmittedAt']),
      reviewedAt: parseDate(json['reviewedAt']),
      approvedAt: parseDate(json['approvedAt']),
      rejectedAt: parseDate(json['rejectedAt']),
      rejectReason: json['rejectReason'] as String?,
      suspendedAt: parseDate(json['suspendedAt']),
      suspendReason: json['suspendReason'] as String?,
      consentAcceptedAt: parseDate(json['consentAcceptedAt']),
      consentVersion: json['consentVersion'] as String?,
      submittedIp: json['submittedIp'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      resubmissionGuide: (() {
        final guideRaw = json['resubmissionGuide'];
        if (guideRaw is Map<String, dynamic>) {
          return VerificationResubmissionGuide.fromJson(guideRaw);
        }
        return null;
      })(),
      reviewLogs: (() {
        final logsRaw = json['reviewLogs'];
        if (logsRaw is! List) return const <VerificationReviewLog>[];
        return logsRaw
            .whereType<Map<String, dynamic>>()
            .map(VerificationReviewLog.fromJson)
            .toList();
      })(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'status': status.label,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    if (fullLegalName != null) 'fullLegalName': fullLegalName,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (nationality != null) 'nationality': nationality,
    if (countryOfResidence != null) 'countryOfResidence': countryOfResidence,
    if (addressLine1 != null) 'addressLine1': addressLine1,
    if (addressLine2 != null) 'addressLine2': addressLine2,
    if (city != null) 'city': city,
    if (stateOrProvince != null) 'stateOrProvince': stateOrProvince,
    if (postalCode != null) 'postalCode': postalCode,
    if (issuingCountry != null) 'issuingCountry': issuingCountry,
    if (governmentIdType != null)
      'governmentIdType': governmentIdType!.apiValue,
    if (governmentIdNumber != null) 'governmentIdNumber': governmentIdNumber,
    if (governmentIdExpiry != null)
      'governmentIdExpiry': governmentIdExpiry!.toIso8601String(),
    if (selfieUrl != null) 'selfieUrl': selfieUrl,
    if (governmentIdFrontUrl != null)
      'governmentIdFrontUrl': governmentIdFrontUrl,
    if (governmentIdBackUrl != null) 'governmentIdBackUrl': governmentIdBackUrl,
    if (liveCapture != null) 'liveCapture': liveCapture,
    if (faceMatchScore != null) 'faceMatchScore': faceMatchScore,
    if (livenessScore != null) 'livenessScore': livenessScore,
    if (riskScore != null) 'riskScore': riskScore,
    'manualReviewRequired': manualReviewRequired,
    if (paymentAccountId != null) 'paymentAccountId': paymentAccountId,
    if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
    if (lastResubmittedAt != null)
      'lastResubmittedAt': lastResubmittedAt!.toIso8601String(),
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    if (rejectedAt != null) 'rejectedAt': rejectedAt!.toIso8601String(),
    if (rejectReason != null) 'rejectReason': rejectReason,
    if (suspendedAt != null) 'suspendedAt': suspendedAt!.toIso8601String(),
    if (suspendReason != null) 'suspendReason': suspendReason,
    if (consentAcceptedAt != null)
      'consentAcceptedAt': consentAcceptedAt!.toIso8601String(),
    if (consentVersion != null) 'consentVersion': consentVersion,
    if (submittedIp != null) 'submittedIp': submittedIp,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (resubmissionGuide != null)
      'resubmissionGuide': {
        if (resubmissionGuide!.reason != null)
          'reason': resubmissionGuide!.reason,
        'fields': resubmissionGuide!.fields,
        if (resubmissionGuide!.updatedAt != null)
          'updatedAt': resubmissionGuide!.updatedAt!.toIso8601String(),
      },
    if (reviewLogs.isNotEmpty)
      'reviewLogs': reviewLogs
          .map(
            (log) => {
              if (log.id != null) 'id': log.id,
              if (log.action != null) 'action': log.action,
              if (log.actorType != null) 'actorType': log.actorType,
              if (log.actorId != null) 'actorId': log.actorId,
              if (log.reason != null) 'reason': log.reason,
              if (log.resubmissionFields.isNotEmpty)
                'resubmissionFields': log.resubmissionFields,
              if (log.createdAt != null)
                'createdAt': log.createdAt!.toIso8601String(),
            },
          )
          .toList(),
  };

  VerificationModel copyWith({
    String? id,
    String? userId,
    TrustStatus? status,
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
    String? selfieUrl,
    String? governmentIdFrontUrl,
    String? governmentIdBackUrl,
    bool? liveCapture,
    double? faceMatchScore,
    double? livenessScore,
    double? riskScore,
    bool? manualReviewRequired,
    String? paymentAccountId,
    DateTime? submittedAt,
    DateTime? lastResubmittedAt,
    DateTime? reviewedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? rejectReason,
    DateTime? suspendedAt,
    String? suspendReason,
    DateTime? consentAcceptedAt,
    String? consentVersion,
    String? submittedIp,
    DateTime? createdAt,
    DateTime? updatedAt,
    VerificationResubmissionGuide? resubmissionGuide,
    List<VerificationReviewLog>? reviewLogs,
  }) {
    return VerificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullLegalName: fullLegalName ?? this.fullLegalName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      nationality: nationality ?? this.nationality,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      stateOrProvince: stateOrProvince ?? this.stateOrProvince,
      postalCode: postalCode ?? this.postalCode,
      issuingCountry: issuingCountry ?? this.issuingCountry,
      governmentIdType: governmentIdType ?? this.governmentIdType,
      governmentIdNumber: governmentIdNumber ?? this.governmentIdNumber,
      governmentIdExpiry: governmentIdExpiry ?? this.governmentIdExpiry,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      governmentIdFrontUrl: governmentIdFrontUrl ?? this.governmentIdFrontUrl,
      governmentIdBackUrl: governmentIdBackUrl ?? this.governmentIdBackUrl,
      liveCapture: liveCapture ?? this.liveCapture,
      faceMatchScore: faceMatchScore ?? this.faceMatchScore,
      livenessScore: livenessScore ?? this.livenessScore,
      riskScore: riskScore ?? this.riskScore,
      manualReviewRequired: manualReviewRequired ?? this.manualReviewRequired,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      submittedAt: submittedAt ?? this.submittedAt,
      lastResubmittedAt: lastResubmittedAt ?? this.lastResubmittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectReason: rejectReason ?? this.rejectReason,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendReason: suspendReason ?? this.suspendReason,
      consentAcceptedAt: consentAcceptedAt ?? this.consentAcceptedAt,
      consentVersion: consentVersion ?? this.consentVersion,
      submittedIp: submittedIp ?? this.submittedIp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resubmissionGuide: resubmissionGuide ?? this.resubmissionGuide,
      reviewLogs: reviewLogs ?? this.reviewLogs,
    );
  }
}
