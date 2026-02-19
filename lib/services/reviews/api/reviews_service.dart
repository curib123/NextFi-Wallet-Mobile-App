import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/reviews_exceptions.dart';
import '../helpers/reviews_helpers.dart';
import '../models/reviews_dtos.dart';
import '../models/reviews_models.dart';
import 'reviews_endpoints.dart';

typedef TokenProvider = Future<String?> Function();

class ReviewsService {
  ReviewsService({required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final TokenProvider tokenProvider;
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
    'success',
    'ok',
    'status',
    'message',
    'error',
    'errors',
  };

  bool _isEnvelopeMap(Map<String, dynamic> map) =>
      map.keys.every((k) => _envelopeKeys.contains(k.toString()));

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Missing JWT token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

    if (data is Map<String, dynamic>) {
      if (data.isEmpty) return null;

      for (final key in keys) {
        if (!data.containsKey(key)) continue;
        final extracted = _extractMap(data[key], keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }

      if (!_isEnvelopeMap(data)) return data;

      for (final value in data.values) {
        final extracted = _extractMap(value, keys: keys, depth: depth + 1);
        if (extracted != null) return extracted;
      }
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
      final items = data.whereType<Map<String, dynamic>>().toList();
      if (items.isNotEmpty) return items;
      for (final item in data) {
        final nested = _extractListMaps(item, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
      return const [];
    }

    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        if (!data.containsKey(key)) continue;
        final nested = _extractListMaps(
          data[key],
          keys: keys,
          depth: depth + 1,
        );
        if (nested.isNotEmpty) return nested;
      }
      for (final value in data.values) {
        final nested = _extractListMaps(value, keys: keys, depth: depth + 1);
        if (nested.isNotEmpty) return nested;
      }
    }

    return const [];
  }

  Future<ReviewModel> createReviewAsBuyer(CreateReviewRequest req) async {
    final res = await _client.post(
      ReviewsHttp.uri(ReviewsEndpoints.createBuyerReview()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'review', 'item']);
    if (map != null) return ReviewModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /reviews',
      body: res.body,
    );
  }

  Future<List<ReviewModel>> listMyReviews(ReviewsQuery query) async {
    final res = await _client.get(
      ReviewsHttp.uri(
        ReviewsEndpoints.listMyReviews(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'reviews', 'list'],
    );
    return items.map(ReviewModel.fromJson).toList();
  }

  Future<ReviewModel> createReviewAsSeller(CreateReviewRequest req) async {
    final res = await _client.post(
      ReviewsHttp.uri(ReviewsEndpoints.createSellerReview()),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );

    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final map = _extractMap(data, keys: const ['data', 'review', 'item']);
    if (map != null) return ReviewModel.fromJson(map);

    throw ApiException(
      res.statusCode,
      'Unexpected response for POST /reviews/seller/me',
      body: res.body,
    );
  }

  Future<List<ReviewModel>> listSellerReviews(ReviewsQuery query) async {
    final res = await _client.get(
      ReviewsHttp.uri(
        ReviewsEndpoints.listSellerReviews(),
        queryParams: query.toQueryMap(),
      ),
      headers: await _headers(),
    );

    ReviewsHttp.ensureOk(res);
    final data = ReviewsHttp.decodeJson<dynamic>(res);
    final items = _extractListMaps(
      data,
      keys: const ['items', 'data', 'reviews', 'list'],
    );
    return items.map(ReviewModel.fromJson).toList();
  }
}
