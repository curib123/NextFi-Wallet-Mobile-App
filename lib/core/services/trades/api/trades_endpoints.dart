class TradesEndpoints {
  static const String base = '/trades';

  static String create() => base;
  static String list() => base;
  static String getOne(String id) => '$base/$id';

  static String confirmRequest(String id) => '$base/$id/confirm-request';
  static String markFiatSent(String id) => '$base/$id/mark-fiat-sent';
  static String confirmFiat(String id) => '$base/$id/confirm-fiat';
  static String cancel(String id) => '$base/$id/cancel';

  static String lockCrypto(String id) => '$base/$id/lock-crypto';
  static String claimCrypto(String id) => '$base/$id/claim-crypto';
  static String refundCrypto(String id) => '$base/$id/refund-crypto';

  static String proofs(String id) => '$base/$id/proofs';
  static String messages(String id) => '$base/$id/messages';

  static String openDispute(String id) => '$base/$id/open-dispute';
  static String disputes() => '/disputes';
  static String dispute(String id) => '/disputes/$id';
  static String disputeEvidence(String id) => '/disputes/$id/evidence';

  static String adminList() => '$base/admin/list';
  static String adminGetOne(String id) => '$base/admin/$id';
  static String adminResolveDispute(String id) =>
      '$base/admin/$id/resolve-dispute';
}
