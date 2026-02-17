enum TrustStatus {
  basic,
  reviewing,
  ready,
  suspended,
  unknown,
}

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
  final DateTime? submittedAt;
  final String? selfieUrl;
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
    this.submittedAt,
    this.selfieUrl,
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

    final rawLogs = json['logs'];

    return VerificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      status: trustStatusFromValue(json['status']),
      submittedAt: parseDate(json['submittedAt']),
      selfieUrl: json['selfieUrl']?.toString(),
      paymentAccountId: json['paymentAccountId']?.toString(),
      reviewedAt: parseDate(json['reviewedAt']),
      approvedAt: parseDate(json['approvedAt']),
      rejectedAt: parseDate(json['rejectedAt']),
      rejectReason: json['rejectReason']?.toString(),
      suspendedAt: parseDate(json['suspendedAt']),
      suspendReason: json['suspendReason']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
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
      (selfieUrl != null && selfieUrl!.trim().isNotEmpty) || submittedAt != null;

  bool get isFinalReviewState =>
      status == TrustStatus.reviewing ||
      status == TrustStatus.ready ||
      status == TrustStatus.suspended;
}
