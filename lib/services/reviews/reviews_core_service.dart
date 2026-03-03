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
  final Map<String, (UserRatingSummary summary, DateTime at)> _summaryCache = {};
  final Map<String, Future<UserRatingSummary>> _summaryInflight = {};
  static const Duration _summaryTtl = Duration(seconds: 60);

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

  /// Get public reviews for an offer (paginated)
  Future<ReviewsPagedResponse> getOfferReviewsPaged({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getOfferReviewsPaged(offerId: offerId, query: query);

  /// Get public reviews for an offer (non-paginated)
  Future<List<ReviewModel>> getOfferReviews({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getOfferReviews(offerId: offerId, query: query);

  /// Get all public reviews for a user by paging until last page.
  Future<List<ReviewModel>> getAllUserReviews({
    required String userId,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return const [];

    var page = 1;
    final out = <ReviewModel>[];
    while (page <= maxPages) {
      final res = await _api.getUserReviewsPaged(
        userId: normalized,
        query: ReviewsListQuery(page: page.toString(), limit: '$pageSize'),
      );
      out.addAll(res.items);
      if (page >= res.meta.totalPages || res.items.isEmpty) break;
      page += 1;
    }
    return out;
  }

  /// Get all public reviews for an offer by paging until last page.
  Future<List<ReviewModel>> getAllOfferReviews({
    required String offerId,
    int pageSize = 100,
    int maxPages = 50,
  }) async {
    final normalized = offerId.trim();
    if (normalized.isEmpty) return const [];

    var page = 1;
    final out = <ReviewModel>[];
    while (page <= maxPages) {
      final res = await _api.getOfferReviewsPaged(
        offerId: normalized,
        query: ReviewsListQuery(page: page.toString(), limit: '$pageSize'),
      );
      out.addAll(res.items);
      if (page >= res.meta.totalPages || res.items.isEmpty) break;
      page += 1;
    }
    return out;
  }

  /// Get average rating for a user
  Future<double?> getUserAverageRating(String userId) async =>
      (await getUserRatingSummary(userId)).averageRating;

  /// Get review count for a user
  Future<int> getUserReviewCount(String userId) async =>
      (await getUserRatingSummary(userId)).reviewCount;

  /// Get rating summary for an offer.
  Future<UserRatingSummary> getOfferRatingSummary(String offerId) async =>
      _api.getOfferRatingSummary(offerId);

  /// Get cached rating summary for a user.
  Future<UserRatingSummary> getUserRatingSummary(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return const UserRatingSummary(averageRating: null, reviewCount: 0);
    }

    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = _summaryCache[normalized];
      if (cached != null && now.difference(cached.$2) < _summaryTtl) {
        return cached.$1;
      }
      final inflight = _summaryInflight[normalized];
      if (inflight != null) return inflight;
    }

    final future = _api.getUserRatingSummary(normalized);
    _summaryInflight[normalized] = future;
    try {
      final summary = await future;
      _summaryCache[normalized] = (summary, now);
      return summary;
    } finally {
      _summaryInflight.remove(normalized);
    }
  }

  void invalidateUserRatingSummary(String userId) {
    _summaryCache.remove(userId.trim());
    _summaryInflight.remove(userId.trim());
  }

  /// Create a new review (requires authentication)
  Future<ReviewModel> create(CreateReviewRequest req) async {
    final created = await _api.create(req);
    // Ensure fresh stats for any visible seller tiles.
    invalidateUserRatingSummary(created.revieweeId);
    invalidateUserRatingSummary(created.reviewerId);
    return created;
  }

  /// Get current user's reviews (requires authentication)
  Future<ReviewsPagedResponse> getMyReviewsPaged({
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async =>
      _api.getMyReviewsPaged(query: query);

  /// Check whether current authenticated user has already reviewed this trade.
  Future<bool> hasReviewedTrade(String tradeId) async {
    final id = tradeId.trim();
    if (id.isEmpty) return false;
    try {
      var page = 1;
      while (true) {
        final res = await _api.getMyReviewsPaged(
          query: ReviewsListQuery(page: page.toString(), limit: '100'),
        );
        if (res.items.any((r) => r.tradeId.trim() == id)) return true;
        if (page >= res.meta.totalPages) break;
        page += 1;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
