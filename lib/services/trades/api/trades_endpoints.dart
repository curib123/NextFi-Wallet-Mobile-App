class TradesEndpoints {
  static const String base = '/trades';

  // ── Buyer (user) routes ────────────────────────────────────────────────────
  static String createTrade() => base;
  static String listMyTrades() => '$base/me';
  static String getMyTrade(String id) => '$base/me/$id';
  static String uploadProof(String id) => '$base/me/$id/proof';

  // ── vF1 Action routes (primary flow) ──────────────────────────────────────
  static String fiatSent(String id) => '$base/$id/actions/fiat-sent';
  static String fiatReceived(String id) => '$base/$id/actions/fiat-received';
  static String fiatSentMerchant(String id) =>
      '$base/$id/actions/fiat-sent-merchant';
  static String confirmReceived(String id) =>
      '$base/$id/actions/confirm-received';
  static String cancelTradeAction(String id) => '$base/$id/actions/cancel';
  static String openDisputeAction(String id) =>
      '$base/$id/actions/open-dispute';

  // ── vF1 Trade chat routes ──────────────────────────────────────────────────
  static String getTradeChat(String id) => '$base/$id/chat';
  static String sendTradeChatMessage(String id) => '$base/$id/chat/messages';

  // ── vF1 Delivery routes ───────────────────────────────────────────────────
  static String deliveryIntent(String id) => '$base/$id/delivery/intent';
  static String deliverySubmit(String id) => '$base/$id/delivery/submit';
  static String getDelivery(String id) => '$base/$id/delivery';

  // ── Seller (merchant) routes ───────────────────────────────────────────────
  static String listSellerTrades() => '$base/seller/me';
  static String getSellerTrade(String id) => '$base/seller/me/$id';

  // ── Legacy endpoints (backward compat) ────────────────────────────────────
  static String markPaid(String id) => '$base/me/$id/paid';
  static String cancelMyTrade(String id) => '$base/me/$id/cancel';
  static String sendMyMessage(String id) => '$base/me/$id/messages';
  static String releaseSellerTrade(String id) =>
      '$base/seller/me/$id/release';
  static String cancelSellerTrade(String id) =>
      '$base/seller/me/$id/cancel';
}
