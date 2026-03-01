import 'package:next_fi/services/offer_payment_method/models/offer_payment_method_dtos.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class OfferPaymentMethodModel {
  final String id;
  final String offerId;
  final String paymentMethodId;
  final String? merchantPaymentAccountId;
  final PaymentMethodModel paymentMethod;
  final MerchantPaymentAccountModel? merchantPaymentAccount;
  final OfferModel? offer;

  const OfferPaymentMethodModel({
    required this.id,
    required this.offerId,
    required this.paymentMethodId,
    this.merchantPaymentAccountId,
    required this.paymentMethod,
    this.merchantPaymentAccount,
    this.offer,
  });
}

class OfferPaymentMethodMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const OfferPaymentMethodMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory OfferPaymentMethodMeta.fromJson(Map<String, dynamic> json) {
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

    return OfferPaymentMethodMeta(
      total: readInt(const ['total', 'count']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit', 'pageSize', 'page_size'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class OfferPaymentMethodPagedResponse {
  final List<OfferPaymentMethodResponse> items;
  final OfferPaymentMethodMeta meta;

  const OfferPaymentMethodPagedResponse({
    required this.items,
    required this.meta,
  });
}
