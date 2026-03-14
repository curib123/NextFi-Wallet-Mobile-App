class OffersEndpoints {
  static const String base = '/offers';

  // Public
  static String publicList() => base;
  static String publicGetOne(String id) => '$base/$id';

  // Merchant
  static String create() => base;
  static String update(String id) => '$base/$id';
  static String pause(String id) => '$base/$id/pause';
  static String resume(String id) => '$base/$id/resume';
  static String cancel(String id) => '$base/$id';
  static String mine() => '$base/me';

  // Admin
  static String adminList() => '$base/admin/list';
}
