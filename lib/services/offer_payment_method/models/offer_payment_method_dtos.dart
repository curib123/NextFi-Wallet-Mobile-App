import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class OfferPaymentMethodResponse {
  final String id;
  final String offerId;
  final String paymentMethodId;
  final String? merchantPaymentAccountId;
  final PaymentMethodModel paymentMethod;
  final MerchantPaymentAccountModel? merchantPaymentAccount;
  final OfferModel? offer;

  const OfferPaymentMethodResponse({
    required this.id,
    required this.offerId,
    required this.paymentMethodId,
    this.merchantPaymentAccountId,
    required this.paymentMethod,
    this.merchantPaymentAccount,
    this.offer,
  });

  factory OfferPaymentMethodResponse.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final paymentMethodJson = json['paymentMethod'];
    final merchantPaymentAccountJson =
        json['merchantPaymentAccount'] ??
        json['merchant_payment_account'] ??
        json['sellerPaymentAccount'] ??
        json['seller_payment_account'];
    final offerJson = json['offer'];
    final merchantPaymentAccountId = readString(const [
      'merchantPaymentAccountId',
      'merchant_payment_account_id',
      'sellerPaymentAccountId',
      'seller_payment_account_id',
    ]);

    return OfferPaymentMethodResponse(
      id: readString(const ['id']),
      offerId: readString(const ['offerId', 'offer_id']),
      paymentMethodId: readString(const [
        'paymentMethodId',
        'payment_method_id',
      ]),
      merchantPaymentAccountId: merchantPaymentAccountId.isEmpty
          ? null
          : merchantPaymentAccountId,
      paymentMethod: paymentMethodJson is Map<String, dynamic>
          ? PaymentMethodModel.fromJson(paymentMethodJson)
          : PaymentMethodModel(id: '', code: '', name: '', isActive: false),
      merchantPaymentAccount: merchantPaymentAccountJson is Map<String, dynamic>
          ? MerchantPaymentAccountModel.fromJson(merchantPaymentAccountJson)
          : null,
      offer: offerJson is Map<String, dynamic>
          ? OfferModel.fromJson(offerJson)
          : null,
    );
  }
}
