enum TrustStatus { basic, reviewing, ready, suspended, unknown }

enum VerificationLogAction {
  submitted,
  approved,
  rejected,
  suspended,
  unsuspended,
  unknown,
}

TrustStatus trustStatusFromValue(dynamic raw) {
  final value = raw?.toString().toUpperCase().trim();
  switch (value) {
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

VerificationLogAction verificationLogActionFromValue(dynamic raw) {
  final value = raw?.toString().toUpperCase().trim();
  switch (value) {
    case 'SUBMITTED':
      return VerificationLogAction.submitted;
    case 'APPROVED':
      return VerificationLogAction.approved;
    case 'REJECTED':
      return VerificationLogAction.rejected;
    case 'SUSPENDED':
      return VerificationLogAction.suspended;
    case 'UNSUSPENDED':
      return VerificationLogAction.unsuspended;
    default:
      return VerificationLogAction.unknown;
  }
}

class VerificationLogModel {
  final String id;
  final VerificationLogAction action;
  final String? description;
  final String? performedBy;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  const VerificationLogModel({
    required this.id,
    required this.action,
    this.description,
    this.performedBy,
    this.metadata,
    this.createdAt,
  });

  factory VerificationLogModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return VerificationLogModel(
      id: json['id']?.toString() ?? '',
      action: verificationLogActionFromValue(json['action']),
      description: json['description']?.toString(),
      performedBy: json['performedBy']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? (json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: parseDate(json['createdAt']),
    );
  }
}

class VerificationModel {
  final String id;
  final String userId;
  final TrustStatus status;
  final String? phoneNumber;
  final DateTime? submittedAt;
  final String? selfieUrl;
  final String? governmentIdFrontUrl;
  final String? governmentIdBackUrl;
  final String? paymentAccountId;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectReason;
  final DateTime? suspendedAt;
  final String? suspendReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic>? user;
  final Map<String, dynamic>? paymentAccount;
  final List<VerificationLogModel> logs;

  const VerificationModel({
    required this.id,
    required this.userId,
    required this.status,
    this.phoneNumber,
    this.submittedAt,
    this.selfieUrl,
    this.governmentIdFrontUrl,
    this.governmentIdBackUrl,
    this.paymentAccountId,
    this.reviewedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectReason,
    this.suspendedAt,
    this.suspendReason,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.paymentAccount,
    this.logs = const [],
  });

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final rawLogs = json['logs'];

    return VerificationModel(
      id: readString(const ['id']) ?? '',
      userId: readString(const ['userId', 'user_id']) ?? '',
      status: trustStatusFromValue(json['status']),
      phoneNumber: readString(const ['phoneNumber', 'phone_number']),
      submittedAt: parseDate(json['submittedAt'] ?? json['submitted_at']),
      selfieUrl: readString(const ['selfieUrl', 'selfie_url']),
      governmentIdFrontUrl: readString(const [
        'governmentIdFrontUrl',
        'government_id_front_url',
      ]),
      governmentIdBackUrl: readString(const [
        'governmentIdBackUrl',
        'government_id_back_url',
      ]),
      paymentAccountId: readString(const [
        'paymentAccountId',
        'payment_account_id',
      ]),
      reviewedAt: parseDate(json['reviewedAt'] ?? json['reviewed_at']),
      approvedAt: parseDate(json['approvedAt'] ?? json['approved_at']),
      rejectedAt: parseDate(json['rejectedAt'] ?? json['rejected_at']),
      rejectReason: readString(const ['rejectReason', 'reject_reason']),
      suspendedAt: parseDate(json['suspendedAt'] ?? json['suspended_at']),
      suspendReason: readString(const ['suspendReason', 'suspend_reason']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      user: json['user'] is Map<String, dynamic>
          ? (json['user'] as Map<String, dynamic>)
          : null,
      paymentAccount: json['paymentAccount'] is Map<String, dynamic>
          ? (json['paymentAccount'] as Map<String, dynamic>)
          : null,
      logs: rawLogs is List
          ? rawLogs
                .whereType<Map<String, dynamic>>()
                .map(VerificationLogModel.fromJson)
                .toList()
          : const [],
    );
  }

  bool get hasSubmittedSelfie =>
      (selfieUrl != null && selfieUrl!.trim().isNotEmpty) ||
      submittedAt != null;

  bool get hasSubmittedRequiredDocuments {
    bool hasValue(String? value) => value != null && value.trim().isNotEmpty;
    return hasValue(phoneNumber) &&
        hasValue(selfieUrl) &&
        hasValue(governmentIdFrontUrl) &&
        hasValue(governmentIdBackUrl);
  }

  bool get isFinalReviewState =>
      status == TrustStatus.reviewing ||
      status == TrustStatus.ready ||
      status == TrustStatus.suspended;
}
