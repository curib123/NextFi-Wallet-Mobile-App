class PaymentMethodModel {
  final String id;
  final String code;
  final String name;
  final String? logo;
  final String? description;
  final String? instructions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentMethodModel({
    required this.id,
    required this.code,
    required this.name,
    this.logo,
    this.description,
    this.instructions,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return PaymentMethodModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
      isActive: json['isActive'] == true,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

class UserPaymentAccountModel {
  final String id;
  final String userId;
  final String paymentMethodId;
  final String? label;
  final String accountName;
  final String? accountNo;
  final String? instructions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PaymentMethodModel? paymentMethod;

  const UserPaymentAccountModel({
    required this.id,
    required this.userId,
    required this.paymentMethodId,
    this.label,
    required this.accountName,
    this.accountNo,
    this.instructions,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.paymentMethod,
  });

  factory UserPaymentAccountModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    final paymentMethodJson = json['paymentMethod'];

    return UserPaymentAccountModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      paymentMethodId: json['paymentMethodId']?.toString() ?? '',
      label: json['label']?.toString(),
      accountName: json['accountName']?.toString() ?? '',
      accountNo: json['accountNo']?.toString(),
      instructions: json['instructions']?.toString(),
      isActive: json['isActive'] == true,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      paymentMethod: paymentMethodJson is Map<String, dynamic>
          ? PaymentMethodModel.fromJson(paymentMethodJson)
          : null,
    );
  }
}