import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class OfferPaymentMethodResponse {
  final String id;
  final String offerId;
  final String paymentMethodId;
  final PaymentMethodModel paymentMethod;
  final OfferModel? offer;

  const OfferPaymentMethodResponse({
    required this.id,
    required this.offerId,
    required this.paymentMethodId,
    required this.paymentMethod,
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
    final offerJson = json['offer'];

    return OfferPaymentMethodResponse(
      id: readString(const ['id']),
      offerId: readString(const ['offerId', 'offer_id']),
      paymentMethodId: readString(const [
        'paymentMethodId',
        'payment_method_id',
      ]),
      paymentMethod: paymentMethodJson is Map<String, dynamic>
          ? PaymentMethodModel.fromJson(paymentMethodJson)
          : PaymentMethodModel(id: '', code: '', name: '', isActive: false),
      offer: offerJson is Map<String, dynamic>
          ? OfferModel.fromJson(offerJson)
          : null,
    );
  }
}
