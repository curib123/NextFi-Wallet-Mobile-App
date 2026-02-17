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
  final String? instructions;
  final bool? isActive;

  const CreateUserPaymentAccountRequest({
    required this.paymentMethodId,
    this.label,
    required this.accountName,
    this.accountNo,
    this.instructions,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        'paymentMethodId': paymentMethodId,
        if (label != null) 'label': label,
        'accountName': accountName,
        if (accountNo != null) 'accountNo': accountNo,
        if (instructions != null) 'instructions': instructions,
        if (isActive != null) 'isActive': isActive,
      };
}

class UpdateUserPaymentAccountRequest {
  final String? paymentMethodId;
  final String? label;
  final String? accountName;
  final String? accountNo;
  final String? instructions;
  final bool? isActive;

  const UpdateUserPaymentAccountRequest({
    this.paymentMethodId,
    this.label,
    this.accountName,
    this.accountNo,
    this.instructions,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (label != null) 'label': label,
        if (accountName != null) 'accountName': accountName,
        if (accountNo != null) 'accountNo': accountNo,
        if (instructions != null) 'instructions': instructions,
        if (isActive != null) 'isActive': isActive,
      };
}
