class CreateReviewRequest {
  final String tradeId;
  final int rating;
  final String? comment;

  const CreateReviewRequest({
    required this.tradeId,
    required this.rating,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('rating must be between 1 and 5');
    }
    return {
      'tradeId': tradeId,
      'rating': rating,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
    };
  }
}

class ReviewsListQuery {
  final String? userId;
  final String? page;
  final String? limit;
  final String? search;

  const ReviewsListQuery({this.userId, this.page, this.limit, this.search});

  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (userId != null && userId!.isNotEmpty) params['userId'] = userId!;
    if (page != null && page!.isNotEmpty) params['page'] = page!;
    if (limit != null && limit!.isNotEmpty) params['limit'] = limit!;
    if (search != null && search!.isNotEmpty) params['q'] = search!;
    return params;
  }
}
