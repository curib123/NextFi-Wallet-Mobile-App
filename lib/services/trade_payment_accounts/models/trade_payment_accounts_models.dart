import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class TradePaymentAccountsContext {
  final String offerId;
  final String offerType;
  final String merchantUserId;
  final List<PaymentMethodModel> paymentMethods;
  final List<UserPaymentAccountModel> merchantAccounts;
  final List<UserPaymentAccountModel> clientAccounts;
  final List<String> compatiblePaymentMethodIds;

  const TradePaymentAccountsContext({
    required this.offerId,
    required this.offerType,
    required this.merchantUserId,
    required this.paymentMethods,
    required this.merchantAccounts,
    required this.clientAccounts,
    required this.compatiblePaymentMethodIds,
  });

  factory TradePaymentAccountsContext.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> asMapList(dynamic v) {
      if (v is! List) return const [];
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    List<String> asStringList(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return TradePaymentAccountsContext(
      offerId: (json['offerId'] ?? json['offer_id'] ?? '').toString(),
      offerType: (json['offerType'] ?? json['offer_type'] ?? '').toString(),
      merchantUserId:
          (json['merchantUserId'] ?? json['merchant_user_id'] ?? '').toString(),
      paymentMethods: asMapList(
        json['paymentMethods'] ?? json['payment_methods'],
      ).map(PaymentMethodModel.fromJson).toList(),
      merchantAccounts: asMapList(
        json['merchantAccounts'] ?? json['merchant_accounts'],
      ).map(UserPaymentAccountModel.fromJson).toList(),
      clientAccounts: asMapList(
        json['clientAccounts'] ?? json['client_accounts'],
      ).map(UserPaymentAccountModel.fromJson).toList(),
      compatiblePaymentMethodIds: asStringList(
        json['compatiblePaymentMethodIds'] ?? json['compatible_payment_method_ids'],
      ),
    );
  }
}
