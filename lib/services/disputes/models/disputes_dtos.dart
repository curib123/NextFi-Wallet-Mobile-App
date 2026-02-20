class OpenDisputeRequest {
  final String tradeId;
  final String reason;

  const OpenDisputeRequest({required this.tradeId, required this.reason});

  Map<String, dynamic> toJson() => {
    'tradeId': tradeId.trim(),
    'reason': reason.trim(),
  };
}

class DisputesQuery {
  final String? tradeId;
  final String? status;
  final String? q;
  final int? page;
  final int? limit;

  const DisputesQuery({
    this.tradeId,
    this.status,
    this.q,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryMap() => {
    if (tradeId != null && tradeId!.trim().isNotEmpty)
      'tradeId': tradeId!.trim(),
    if (status != null && status!.trim().isNotEmpty) 'status': status!.trim(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}
