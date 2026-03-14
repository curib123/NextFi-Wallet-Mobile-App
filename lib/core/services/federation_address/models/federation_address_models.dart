class FederationAddressModel {
  FederationAddressModel({
    required this.id,
    required this.userId,
    required this.alias,
    required this.domain,
    required this.accountId,
    required this.isActive,
    this.memo,
    this.memoType,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String alias;
  final String domain;
  final String accountId;
  final String? memo;
  final String? memoType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get federationAddress => '$alias*$domain';

  factory FederationAddressModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    final accountId = (json['accountId'] ?? json['account_id'] ?? '')
        .toString()
        .trim();

    return FederationAddressModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      alias: (json['alias'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      accountId: accountId,
      memo: json['memo']?.toString(),
      memoType: (json['memoType'] ?? json['memo_type'])?.toString(),
      isActive: json['isActive'] == true || json['is_active'] == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class FederationResolveResponse {
  FederationResolveResponse({
    required this.stellarAddress,
    required this.accountId,
    this.memo,
    this.memoType,
  });

  final String stellarAddress;
  final String accountId;
  final String? memo;
  final String? memoType;

  factory FederationResolveResponse.fromJson(Map<String, dynamic> json) {
    return FederationResolveResponse(
      stellarAddress: (json['stellar_address'] ?? json['stellarAddress'] ?? '')
          .toString(),
      accountId: (json['account_id'] ?? json['accountId'] ?? '').toString(),
      memo: json['memo']?.toString(),
      memoType: (json['memo_type'] ?? json['memoType'])?.toString(),
    );
  }
}
