class ReviewsEndpoints {
  static const String base = '/reviews';

  static String createBuyerReview() => base;
  static String listMyReviews() => '$base/me';
  static String createSellerReview() => '$base/seller/me';
  static String listSellerReviews() => '$base/seller/me';
}
