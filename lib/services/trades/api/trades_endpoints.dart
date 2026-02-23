class TradesEndpoints {
  static const String base = '/trades';

  static String create() => base;
  static String list() => base;
  static String getOne(String id) => '$base/$id';
  static String markFiatSent(String id) => '$base/$id/mark-fiat-sent';
  static String confirmFiat(String id) => '$base/$id/confirm-fiat';
  static String cancel(String id) => '$base/$id/cancel';
  static String proofs(String id) => '$base/$id/proofs';
  static String messages(String id) => '$base/$id/messages';

  static String adminList() => '$base/admin/list';
  static String adminGetOne(String id) => '$base/admin/$id';
}
