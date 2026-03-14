/// Reviews API endpoints
class ReviewsEndpoints {
  static const String base = '/reviews';

  /// Get reviews for a specific user (public)
  static String userReviews(String userId) => '$base/user/$userId';

  /// Get reviews for a specific offer (public)
  static String offerReviews(String offerId) => '$base/offer/$offerId';

  /// Get current user's reviews (authenticated)
  static String me() => '$base/me';

  /// Create a new review (authenticated)
  static String create() => base;

  /// Admin: List all reviews
  static String adminList() => '$base/admin/list';

  /// Admin: Get single review detail
  static String adminDetail(String id) => '$base/admin/$id';
}
