class MerchantProfileEndpoints {
  static const String base = '/merchant-profiles';

  static String me() => '$base/me';
  static String request() => '$base/request';
  static String meAvailability() => '$base/me/availability';
  static String meBusinessDocs() => '$base/me/business-docs';
  static String publicProfile(String userId) => '$base/public/$userId';
}
