import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/reviews_service.dart';
import 'models/reviews_dtos.dart';
import 'models/reviews_models.dart';

/// Reviews core service - main entry point for reviews functionality
class ReviewsCoreService {
  ReviewsCoreService._();

  static final ReviewsCoreService I = ReviewsCoreService._();

  late final ReviewsService _api = ReviewsService(
    tokenProvider: _safeTokenProvider,
  );

  static Future<String?> _safeTokenProvider() async {
    try {
      final storage = TokenStorage();
      return await storage.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// Get public reviews for a user (paginated)
  Future<ReviewsPagedResponse> getUserReviewsPaged({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getUserReviewsPaged(userId: userId, query: query);

  /// Get public reviews for a user (non-paginated)
  Future<List<ReviewModel>> getUserReviews({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getUserReviews(userId: userId, query: query);

  /// Get average rating for a user
  Future<double?> getUserAverageRating(String userId) async =>
      _api.getUserAverageRating(userId);

  /// Get review count for a user
  Future<int> getUserReviewCount(String userId) async =>
      _api.getUserReviewCount(userId);

  /// Create a new review (requires authentication)
  Future<ReviewModel> create(CreateReviewRequest req) async =>
      _api.create(req);

  /// Get current user's reviews (requires authentication)
  Future<ReviewsPagedResponse> getMyReviewsPaged({
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getMyReviewsPaged(query: query);
}
