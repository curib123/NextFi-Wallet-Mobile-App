class OffersEndpoints {
  static const String base = '/offers';

  static String publicList() => base;
  static String recommendedFeed() => '$base/me/recommended/feed';
  static String publicById(String id) => '$base/$id';

  static String myList() => '$base/me/list';
  static String createMyOffer() => '$base/me';
  static String patchMyOffer(String id) => '$base/me/$id';
  static String deleteMyOffer(String id) => '$base/me/$id';
}
