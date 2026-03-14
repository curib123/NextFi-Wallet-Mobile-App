/// Review model representing a post-trade rating/feedback
class ReviewModel {
  final String id;
  final String tradeId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.tradeId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    int? readInt(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    return ReviewModel(
      id: readString(const ['id']),
      tradeId: readString(const ['tradeId', 'trade_id']),
      reviewerId: readString(const ['reviewerId', 'reviewer_id']),
      revieweeId: readString(const ['revieweeId', 'reviewee_id']),
      rating: readInt(const ['rating']) ?? 0,
      comment: (() {
        final text = readString(
          const ['comment', 'feedback', 'message', 'review', 'remarks'],
        );
        return text.isEmpty ? null : text;
      })(),
      createdAt: readDate(const ['createdAt', 'created_at']),
    );
  }
}

/// Reviews meta for pagination
class ReviewsMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ReviewsMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ReviewsMeta.fromJson(Map<String, dynamic> json) {
    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final v = json[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return fallback;
    }

    return ReviewsMeta(
      total: readInt(const ['total', 'count']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit', 'pageSize', 'page_size'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

/// Paginated reviews response
class ReviewsPagedResponse {
  final List<ReviewModel> items;
  final ReviewsMeta meta;

  const ReviewsPagedResponse({required this.items, required this.meta});
}

/// Lightweight user rating aggregate.
class UserRatingSummary {
  final double? averageRating;
  final int reviewCount;

  const UserRatingSummary({
    required this.averageRating,
    required this.reviewCount,
  });
}
