class ProfileEndpoints {
  static const String base = '/profile';

  static String me() => '$base/me';
  static String merchantRequestStatus() => '$base/me/merchant-request';
  static String requestMerchantAccess() => '$base/me/request-merchant';
}
