class MerchantPaymentAccountListQuery {
  final String? q;
  final String? paymentMethodId;
  final bool? activeOnly;
  final int? page;
  final int? limit;

  final String? sellerId;

  final String? userId;

  final String? merchantProfileId;

  const MerchantPaymentAccountListQuery({
    this.q,
    this.paymentMethodId,
    this.activeOnly,
    this.page,
    this.limit,
    this.sellerId,
    this.userId,
    this.merchantProfileId,
  });

  Map<String, String> toQueryMap() => {
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (paymentMethodId != null && paymentMethodId!.trim().isNotEmpty)
      'paymentMethodId': paymentMethodId!.trim(),
    if (activeOnly != null) 'activeOnly': activeOnly! ? 'true' : 'false',
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
    if (sellerId != null && sellerId!.trim().isNotEmpty)
      'sellerId': sellerId!.trim(),
    if (userId != null && userId!.trim().isNotEmpty) 'userId': userId!.trim(),
    if (merchantProfileId != null && merchantProfileId!.trim().isNotEmpty)
      'merchantProfileId': merchantProfileId!.trim(),
  };
}

class CreateMerchantPaymentAccountRequest {
  final String paymentMethodId;
  final String accountName;
  final String? accountNo;
  final String? label;
  final String? instructions;
  final bool? isActive;

  const CreateMerchantPaymentAccountRequest({
    required this.paymentMethodId,
    required this.accountName,
    this.accountNo,
    this.label,
    this.instructions,
    this.isActive,
  });

  static String? _trim(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    'paymentMethodId': paymentMethodId.trim(),
    'accountName': accountName.trim(),
    if (_trim(accountNo) != null) 'accountNo': _trim(accountNo),
    if (_trim(label) != null) 'label': _trim(label),
    if (_trim(instructions) != null) 'instructions': _trim(instructions),
    if (isActive != null) 'isActive': isActive,
  };
}

class UpdateMerchantPaymentAccountRequest {
  final String? paymentMethodId;
  final String? accountName;
  final String? accountNo;
  final String? label;
  final String? instructions;
  final bool? isActive;

  const UpdateMerchantPaymentAccountRequest({
    this.paymentMethodId,
    this.accountName,
    this.accountNo,
    this.label,
    this.instructions,
    this.isActive,
  });

  static String? _trim(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    if (_trim(paymentMethodId) != null)
      'paymentMethodId': _trim(paymentMethodId),
    if (_trim(accountName) != null) 'accountName': _trim(accountName),
    if (_trim(accountNo) != null) 'accountNo': _trim(accountNo),
    if (_trim(label) != null) 'label': _trim(label),
    if (_trim(instructions) != null) 'instructions': _trim(instructions),
    if (isActive != null) 'isActive': isActive,
  };
}
