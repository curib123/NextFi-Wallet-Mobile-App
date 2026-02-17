enum TrustStatus {
  basic,
  reviewing,
  ready,
  suspended,
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
  });

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

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
    );
  }

  bool get hasSubmittedSelfie =>
      (selfieUrl != null && selfieUrl!.trim().isNotEmpty) || submittedAt != null;

  bool get isFinalReviewState =>
      status == TrustStatus.reviewing ||
      status == TrustStatus.ready ||
      status == TrustStatus.suspended;
}
