class PaymentMethodsQuery {
  final bool? activeOnly;
  final String? q;

  const PaymentMethodsQuery({this.activeOnly, this.q});

  Map<String, String> toQueryMap() => {
    if (activeOnly != null) 'activeOnly': activeOnly.toString(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
  };
}

class CreatePaymentMethodRequest {
  final String code;
  final String name;
  final String? logo;
  final String? description;
  final String? instructions;
  final bool? isActive;

  const CreatePaymentMethodRequest({
    required this.code,
    required this.name,
    this.logo,
    this.description,
    this.instructions,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (logo != null) 'logo': logo,
    if (description != null) 'description': description,
    if (instructions != null) 'instructions': instructions,
    if (isActive != null) 'isActive': isActive,
  };
}

class UpdatePaymentMethodRequest {
  final String? code;
  final String? name;
  final String? logo;
  final String? description;
  final String? instructions;
  final bool? isActive;

  const UpdatePaymentMethodRequest({
    this.code,
    this.name,
    this.logo,
    this.description,
    this.instructions,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
    if (code != null) 'code': code,
    if (name != null) 'name': name,
    if (logo != null) 'logo': logo,
    if (description != null) 'description': description,
    if (instructions != null) 'instructions': instructions,
    if (isActive != null) 'isActive': isActive,
  };
}

class PaymentAccountsQuery {
  final bool? activeOnly;
  final String? q;
  final String? paymentMethodId;
  final int? page;
  final int? limit;

  const PaymentAccountsQuery({
    this.activeOnly,
    this.q,
    this.paymentMethodId,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryMap() => {
    if (activeOnly != null) 'activeOnly': activeOnly.toString(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (paymentMethodId != null && paymentMethodId!.trim().isNotEmpty)
      'paymentMethodId': paymentMethodId!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}

class CreateUserPaymentAccountRequest {
  final String paymentMethodId;
  final String? label;
  final String accountName;
  final String? accountNo;
  final String? assetReceiverAddress;
  final String? instructions;
  final bool? isActive;

  const CreateUserPaymentAccountRequest({
    required this.paymentMethodId,
    this.label,
    required this.accountName,
    this.accountNo,
    this.assetReceiverAddress,
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
    if (_trim(label) != null) 'label': _trim(label),
    'accountName': accountName.trim(),
    if (_trim(accountNo) != null) 'accountNo': _trim(accountNo),
    if (_trim(assetReceiverAddress) != null)
      'assetReceiverAddress': _trim(assetReceiverAddress),
    if (_trim(instructions) != null) 'instructions': _trim(instructions),
    if (isActive != null) 'isActive': isActive,
  };
}

class UpdateUserPaymentAccountRequest {
  final String? paymentMethodId;
  final String? label;
  final String? accountName;
  final String? accountNo;
  final String? assetReceiverAddress;
  final String? instructions;
  final bool? isActive;

  const UpdateUserPaymentAccountRequest({
    this.paymentMethodId,
    this.label,
    this.accountName,
    this.accountNo,
    this.assetReceiverAddress,
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
    if (_trim(label) != null) 'label': _trim(label),
    if (_trim(accountName) != null) 'accountName': _trim(accountName),
    if (_trim(accountNo) != null) 'accountNo': _trim(accountNo),
    if (_trim(assetReceiverAddress) != null)
      'assetReceiverAddress': _trim(assetReceiverAddress),
    if (_trim(instructions) != null) 'instructions': _trim(instructions),
    if (isActive != null) 'isActive': isActive,
  };
}
