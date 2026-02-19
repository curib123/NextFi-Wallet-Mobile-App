class TradesEndpoints {
  static const String base = '/trades';

  static String createTrade() => base;
  static String listMyTrades() => '$base/me';
  static String getMyTrade(String id) => '$base/me/$id';
  static String markPaid(String id) => '$base/me/$id/paid';
  static String cancelMyTrade(String id) => '$base/me/$id/cancel';
  static String uploadProof(String id) => '$base/me/$id/proof';
  static String sendMyMessage(String id) => '$base/me/$id/messages';

  static String listSellerTrades() => '$base/seller/me';
  static String getSellerTrade(String id) => '$base/seller/me/$id';
  static String releaseSellerTrade(String id) => '$base/seller/me/$id/release';
  static String cancelSellerTrade(String id) => '$base/seller/me/$id/cancel';
}
