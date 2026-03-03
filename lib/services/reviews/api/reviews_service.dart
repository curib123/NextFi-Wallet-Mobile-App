import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:next_fi/services/base_url/base_url.dart';

import '../models/reviews_dtos.dart';
import '../models/reviews_models.dart';
import 'reviews_endpoints.dart';

/// Reviews HTTP helper
class ReviewsHttp {
  static Uri uri(String path, {Map<String, String>? queryParams}) {
    final base = Uri.parse('$centralized_baseUrl$path');
    if (queryParams == null || queryParams.isEmpty) return base;
    final merged = <String, String>{...base.queryParameters, ...queryParams};
    return base.replace(queryParameters: merged);
  }

  static T decodeJson<T>(http.Response res) {
    if (res.body.isEmpty) return {} as T;
    return jsonDecode(res.body) as T;
  }

  static void ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('Request failed: ${res.statusCode} - ${res.body}');
  }
}

/// Reviews API service
class ReviewsService {
  ReviewsService({
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  static const Set<String> _envelopeKeys = {
    'data',
    'item',
    'items',
    'review',
    'reviews',
    'meta',
    'pagination',
    'page',
    'limit',
    'total',
    'totalPages',
    'total_pages',
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
  };

  Future<Map<String, String>> _publicHeaders() async {
    // Public reviews route should not depend on JWT validity.
    // Sending an expired/invalid token can cause avoidable 401s.
    return const {'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw Exception('Missing JWT token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k.toString()));

  Map<String, dynamic>? _extractMap(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8) return null;
    if (data == null || data == '') return null;
    if (data is String && data.trim().toLowerCase() == 'null') return null;

    if (data is List) {
      for (final item in data) {
        final extracted = _extractMap(item, keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }
      return null;
    }

    final map = _asStringKeyMap(data);
    if (map == null || map.isEmpty) return null;

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final extracted = _extractMap(map[key], keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
    }

    if (!_isEnvelopeMap(map)) return map;

    for (final value in map.values) {
      final extracted = _extractMap(value, keys: keys, depth: depth + 1);
      if (extracted != null) return extracted;
    }

    return null;
  }

  List<Map<String, dynamic>> _extractListMaps(
    dynamic data, {
    List<String> keys = const [],
    int depth = 0,
  }) {
    if (depth > 8 || data == null) return const [];

    if (data is List) {
      final items = data
          .map(_asStringKeyMap)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (items.isNotEmpty) return items;

      for (final item in data) {
        final nested = _extractListMaps(item, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    final map = _asStringKeyMap(data);
    if (map == null) return const [];

    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      final nested = _extractListMaps(map[key], keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    for (final value in map.values) {
      final nested = _extractListMaps(value, keys: keys, depth: depth + 1);
      if (nested.isNotEmpty) return nested;
    }

    return const [];
  }

  ReviewsMeta _extractMeta(dynamic data, {required int fallbackCount}) {
    final map = _asStringKeyMap(data);
    if (map != null) {
      final meta = _asStringKeyMap(map['meta']);
      if (meta != null) return ReviewsMeta.fromJson(meta);

      final pagination = _asStringKeyMap(map['pagination']);
      if (pagination != null) return ReviewsMeta.fromJson(pagination);

      if (map.containsKey('page') ||
          map.containsKey('limit') ||
          map.containsKey('total') ||
          map.containsKey('totalPages') ||
          map.containsKey('total_pages')) {
        return ReviewsMeta.fromJson(map);
      }
    }

    return ReviewsMeta(
      total: fallbackCount,
      page: 1,
      limit: fallbackCount == 0 ? 20 : fallbackCount,
      totalPages: 1,
    );
  }

  /// Get public reviews for a user
  Future<ReviewsPagedResponse> getUserReviewsPaged({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async {
    final res = await _client.get(
      ReviewsHttp.uri(
        ReviewsEndpoints.userReviews(userId),
        queryParams: query.toQueryParams(),
      ),
      headers: await _publicHeaders(),
    );
    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'reviews', 'list'],
    ).map(ReviewModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return ReviewsPagedResponse(items: items, meta: meta);
  }

  /// Get list of reviews for a user (non-paginated)
  Future<List<ReviewModel>> getUserReviews({
    required String userId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async {
    final page = await getUserReviewsPaged(userId: userId, query: query);
    return page.items;
  }

  /// Get public reviews for an offer
  Future<ReviewsPagedResponse> getOfferReviewsPaged({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async {
    final res = await _client.get(
      ReviewsHttp.uri(
        ReviewsEndpoints.offerReviews(offerId),
        queryParams: query.toQueryParams(),
      ),
      headers: await _publicHeaders(),
    );
    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'reviews', 'list'],
    ).map(ReviewModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return ReviewsPagedResponse(items: items, meta: meta);
  }

  /// Get list of reviews for an offer (non-paginated)
  Future<List<ReviewModel>> getOfferReviews({
    required String offerId,
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async {
    final page = await getOfferReviewsPaged(offerId: offerId, query: query);
    return page.items;
  }

  /// Get average rating for a user
  Future<double?> getUserAverageRating(String userId) async {
    final summary = await getUserRatingSummary(userId);
    return summary.averageRating;
  }

  /// Get review count for a user
  Future<int> getUserReviewCount(String userId) async {
    final summary = await getUserRatingSummary(userId);
    return summary.reviewCount;
  }

  /// Get rating summary for a user using paginated public endpoint.
  Future<UserRatingSummary> getUserRatingSummary(String userId) async {
    try {
      final first = await getUserReviewsPaged(
        userId: userId,
        query: const ReviewsListQuery(page: '1', limit: '100'),
      );
      if (first.items.isEmpty) {
        return const UserRatingSummary(averageRating: null, reviewCount: 0);
      }

      var total = first.items.fold<int>(0, (sum, r) => sum + r.rating);
      var count = first.items.length;

      final totalPages = first.meta.totalPages <= 0 ? 1 : first.meta.totalPages;
      for (var page = 2; page <= totalPages; page++) {
        final next = await getUserReviewsPaged(
          userId: userId,
          query: ReviewsListQuery(page: page.toString(), limit: '100'),
        );
        total += next.items.fold<int>(0, (sum, r) => sum + r.rating);
        count += next.items.length;
      }

      if (count == 0) {
        return const UserRatingSummary(averageRating: null, reviewCount: 0);
      }
      return UserRatingSummary(averageRating: total / count, reviewCount: count);
    } catch (_) {
      return const UserRatingSummary(averageRating: null, reviewCount: 0);
    }
  }

  /// Get rating summary for an offer using paginated public endpoint.
  Future<UserRatingSummary> getOfferRatingSummary(String offerId) async {
    try {
      final first = await getOfferReviewsPaged(
        offerId: offerId,
        query: const ReviewsListQuery(page: '1', limit: '100'),
      );
      if (first.items.isEmpty) {
        return const UserRatingSummary(averageRating: null, reviewCount: 0);
      }

      var total = first.items.fold<int>(0, (sum, r) => sum + r.rating);
      var count = first.items.length;

      final totalPages = first.meta.totalPages <= 0 ? 1 : first.meta.totalPages;
      for (var page = 2; page <= totalPages; page++) {
        final next = await getOfferReviewsPaged(
          offerId: offerId,
          query: ReviewsListQuery(page: page.toString(), limit: '100'),
        );
        total += next.items.fold<int>(0, (sum, r) => sum + r.rating);
        count += next.items.length;
      }

      if (count == 0) {
        return const UserRatingSummary(averageRating: null, reviewCount: 0);
      }
      return UserRatingSummary(averageRating: total / count, reviewCount: count);
    } catch (_) {
      return const UserRatingSummary(averageRating: null, reviewCount: 0);
    }
  }

  /// Create a new review (authenticated)
  Future<ReviewModel> create(CreateReviewRequest req) async {
    final res = await _client.post(
      ReviewsHttp.uri(ReviewsEndpoints.create()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'item', 'review']);
    if (map != null) return ReviewModel.fromJson(map);
    throw Exception('Unexpected response for POST /reviews');
  }

  /// Get current user's reviews (authenticated)
  Future<ReviewsPagedResponse> getMyReviewsPaged({
    ReviewsListQuery query = const ReviewsListQuery(),
  }) async {
    final res = await _client.get(
      ReviewsHttp.uri(
        ReviewsEndpoints.me(),
        queryParams: query.toQueryParams(),
      ),
      headers: await _headers(),
    );
    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'reviews', 'list'],
    ).map(ReviewModel.fromJson).toList();
    final meta = _extractMeta(data, fallbackCount: items.length);
    return ReviewsPagedResponse(items: items, meta: meta);
  }

  void dispose() => _client.close();
}
