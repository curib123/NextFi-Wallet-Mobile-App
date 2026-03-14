class MerchantPaymentAccountEndpoints {
  static const String base = '/merchant-payment-accounts';

  static String list() => base;
  static String create() => base;
  static String getOne(String id) => '$base/$id';
  static String update(String id) => '$base/$id';
  static String toggle(String id) => '$base/$id/toggle';
  static String remove(String id) => '$base/$id';
}
