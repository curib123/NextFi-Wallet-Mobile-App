class DisputesEndpoints {
  static const String base = '/disputes';

  static String open() => base;
  static String myList() => '$base/me';
  static String sellerList() => '$base/seller/me';
  static String uploadEvidence(String id) => '$base/$id/evidence';
}
