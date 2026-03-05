class PaymentMethodsQuery {
  final bool? activeOnly;
  final String? q;

  const PaymentMethodsQuery({
    this.activeOnly,
    this.q,
  });

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

  const PaymentAccountsQuery({
    this.activeOnly,
    this.q,
    this.paymentMethodId,
  });

  Map<String, String> toQueryMap() => {
    if (activeOnly != null) 'activeOnly': activeOnly.toString(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (paymentMethodId != null && paymentMethodId!.trim().isNotEmpty)
      'paymentMethodId': paymentMethodId!.trim(),
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

  Map<String, dynamic> toJson() => {
    'paymentMethodId': paymentMethodId,
    if (label != null) 'label': label,
    'accountName': accountName,
    if (accountNo != null) 'accountNo': accountNo,
    if (assetReceiverAddress != null)
      'assetReceiverAddress': assetReceiverAddress,
    if (instructions != null) 'instructions': instructions,
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

  Map<String, dynamic> toJson() => {
    if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
    if (label != null) 'label': label,
    if (accountName != null) 'accountName': accountName,
    if (accountNo != null) 'accountNo': accountNo,
    if (assetReceiverAddress != null)
      'assetReceiverAddress': assetReceiverAddress,
    if (instructions != null) 'instructions': instructions,
    if (isActive != null) 'isActive': isActive,
  };
}
