class MerchantPaymentAccountModel {
  final String id;
  final String merchantProfileId;
  final String paymentMethodId;
  final String accountName;
  final String? accountNo;
  final String? label;
  final String? instructions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic>? paymentMethod;

  const MerchantPaymentAccountModel({
    required this.id,
    required this.merchantProfileId,
    required this.paymentMethodId,
    required this.accountName,
    this.accountNo,
    this.label,
    this.instructions,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
    this.paymentMethod,
  });

  factory MerchantPaymentAccountModel.fromJson(Map<String, dynamic> json) {
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

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v == 'true' || v == '1') return true;
          if (v == 'false' || v == '0') return false;
        }
      }
      return fallback;
    }

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final parsed = parseDate(json[key]);
        if (parsed != null) return parsed;
      }
      return null;
    }

    return MerchantPaymentAccountModel(
      id: readString(const ['id']) ?? '',
      merchantProfileId:
          readString(const ['merchantProfileId', 'merchant_profile_id']) ?? '',
      paymentMethodId:
          readString(const ['paymentMethodId', 'payment_method_id']) ?? '',
      accountName: readString(const ['accountName', 'account_name']) ?? '',
      accountNo: readString(const ['accountNo', 'account_no']),
      label: readString(const ['label']),
      instructions: readString(const ['instructions']),
      isActive: readBool(const ['isActive', 'is_active']),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
      paymentMethod: json['paymentMethod'] is Map<String, dynamic>
          ? (json['paymentMethod'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MerchantPaymentAccountMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const MerchantPaymentAccountMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory MerchantPaymentAccountMeta.fromJson(Map<String, dynamic> json) {
    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final v = json[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return fallback;
    }

    return MerchantPaymentAccountMeta(
      total: readInt(const ['total', 'count']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit', 'pageSize', 'page_size'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class MerchantPaymentAccountPagedResponse {
  final List<MerchantPaymentAccountModel> items;
  final MerchantPaymentAccountMeta meta;

  const MerchantPaymentAccountPagedResponse({
    required this.items,
    required this.meta,
  });
}
