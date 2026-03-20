class ReviewsEndpoints {
  static const String base = '/reviews';

  static String userReviews(String userId) => '$base/user/$userId';

  static String offerReviews(String offerId) => '$base/offer/$offerId';

  static String me() => '$base/me';

  static String create() => base;

  static String adminList() => '$base/admin/list';

  static String adminDetail(String id) => '$base/admin/$id';
}
