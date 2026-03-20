import 'package:next_fi/core/services/secure_storage/token_storage.dart';

import 'api/reviews_service.dart';
import 'models/reviews_dtos.dart';
import 'models/reviews_models.dart';

class ReviewsCoreService {
  ReviewsCoreService._();

  static final ReviewsCoreService I = ReviewsCoreService._();

  late final ReviewsService _api = ReviewsService(
    tokenProvider: _safeTokenProvider,
  );
  final Map<String, (UserRatingSummary summary, DateTime at)> _summaryCache =
      {};
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

  Future<ReviewsPagedResponse> getUserReviewsPaged({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async => _api.getUserReviewsPaged(userId: userId, query: query);

  Future<List<ReviewModel>> getUserReviews({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async => _api.getUserReviews(userId: userId, query: query);

  Future<ReviewsPagedResponse> getOfferReviewsPaged({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async => _api.getOfferReviewsPaged(offerId: offerId, query: query);

  Future<List<ReviewModel>> getOfferReviews({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async => _api.getOfferReviews(offerId: offerId, query: query);

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

  Future<double?> getUserAverageRating(String userId) async =>
      (await getUserRatingSummary(userId)).averageRating;

  Future<int> getUserReviewCount(String userId) async =>
      (await getUserRatingSummary(userId)).reviewCount;

  Future<UserRatingSummary> getOfferRatingSummary(String offerId) async =>
      _api.getOfferRatingSummary(offerId);

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

  Future<ReviewModel> create(CreateReviewRequest req) async {
    final created = await _api.create(req);
    invalidateUserRatingSummary(created.revieweeId);
    invalidateUserRatingSummary(created.reviewerId);
    return created;
  }

  Future<ReviewsPagedResponse> getMyReviewsPaged({
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async => _api.getMyReviewsPaged(query: query);

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
