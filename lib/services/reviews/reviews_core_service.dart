import 'dart:async';

import 'package:next_fi/services/secure_storage/token_storage.dart';

import 'api/reviews_service.dart';
import 'models/reviews_dtos.dart';
import 'models/reviews_models.dart';

class ReviewsCoreService {
  ReviewsCoreService._();

  static final ReviewsCoreService I = ReviewsCoreService._();
  static final StreamController<void> _changesCtrl =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesCtrl.stream;

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

  Future<ReviewModel> createReviewAsBuyer(CreateReviewRequest req) async {
    final review = await _api.createReviewAsBuyer(req);
    _emitChanged();
    return review;
  }

  Future<List<ReviewModel>> listMyReviews(ReviewsQuery query) async =>
      _api.listMyReviews(query);

  Future<ReviewModel> createReviewAsSeller(CreateReviewRequest req) async {
    final review = await _api.createReviewAsSeller(req);
    _emitChanged();
    return review;
  }

  Future<List<ReviewModel>> listSellerReviews(ReviewsQuery query) async =>
      _api.listSellerReviews(query);

  void _emitChanged() {
    if (!_changesCtrl.isClosed) {
      _changesCtrl.add(null);
    }
  }
}
