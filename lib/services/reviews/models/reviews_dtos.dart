class CreateReviewRequest {
  final String tradeId;
  final int rating;
  final String? comment;

  const CreateReviewRequest({
    required this.tradeId,
    required this.rating,
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'tradeId': tradeId.trim(),
    'rating': rating,
    if (comment != null && comment!.trim().isNotEmpty)
      'comment': comment!.trim(),
  };
}

class ReviewsQuery {
  final String? tradeId;
  final String? q;
  final int? page;
  final int? limit;

  const ReviewsQuery({this.tradeId, this.q, this.page, this.limit});

  Map<String, String> toQueryMap() => {
    if (tradeId != null && tradeId!.trim().isNotEmpty)
      'tradeId': tradeId!.trim(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}
