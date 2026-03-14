class FederationLookupQuery {
  const FederationLookupQuery({
    required this.q,
    this.type = 'name',
    this.domain,
  });

  final String q;
  final String type;
  final String? domain;

  Map<String, String> toQueryMap() => {
    'q': q.trim(),
    'type': type.trim().isEmpty ? 'name' : type.trim(),
    if (domain != null && domain!.trim().isNotEmpty) 'domain': domain!.trim(),
  };
}

class CreateFederationAddressRequest {
  const CreateFederationAddressRequest({
    required this.alias,
    this.domain,
    required this.accountId,
    this.memo,
    this.memoType,
    this.isActive,
  });

  final String alias;
  final String? domain;
  final String accountId;
  final String? memo;
  final String? memoType;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
    'alias': alias.trim(),
    if (domain != null && domain!.trim().isNotEmpty) 'domain': domain!.trim(),
    'accountId': accountId.trim(),
    if (memo != null && memo!.trim().isNotEmpty) 'memo': memo!.trim(),
    if (memoType != null && memoType!.trim().isNotEmpty)
      'memoType': memoType!.trim(),
    if (isActive != null) 'isActive': isActive,
  };
}

class UpdateFederationAddressRequest {
  const UpdateFederationAddressRequest({
    this.alias,
    this.domain,
    this.accountId,
    this.memo,
    this.memoType,
    this.isActive,
  });

  final String? alias;
  final String? domain;
  final String? accountId;
  final String? memo;
  final String? memoType;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
    if (alias != null) 'alias': alias,
    if (domain != null) 'domain': domain,
    if (accountId != null) 'accountId': accountId,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
    if (isActive != null) 'isActive': isActive,
  };
}
