class TradePaymentAccountsEndpoints {
  static const String base = '/trade-payment-accounts';

  static String byOffer(String offerId) => '$base/offers/$offerId';
}
