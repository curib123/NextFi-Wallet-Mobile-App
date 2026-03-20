class OfferPaymentMethodEndpoints {
  static const String base = '/offer-payment-methods';

  static String list() => base;
  static String getById(String id) => '$base/$id';
  static String getByOffer(String offerId) => '$base/offer/$offerId';
  static String getByPaymentMethod(String paymentMethodId) =>
      '$base/payment-method/$paymentMethodId';
}
