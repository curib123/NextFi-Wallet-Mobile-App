class OfferPaymentMethodEndpoints {
  static const String base = '/offer-payment-methods';

  // Public endpoints (no authentication required)
  static String list() => base;
  static String getById(String id) => '$base/$id';
  static String getByOffer(String offerId) => '$base/offer/$offerId';
  static String getByPaymentMethod(String paymentMethodId) => '$base/payment-method/$paymentMethodId';
}