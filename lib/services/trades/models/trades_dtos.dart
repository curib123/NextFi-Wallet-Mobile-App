class CreateTradeRequest {
  final String offerId;
  final double amount;
  final String sellerPaymentAccountId;
  final String buyerPaymentAccountId;
  final String? note;

  const CreateTradeRequest({
    required this.offerId,
    required this.amount,
    required this.sellerPaymentAccountId,
    required this.buyerPaymentAccountId,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId.trim(),
    'amount': amount,
    'sellerPaymentAccountId': sellerPaymentAccountId.trim(),
    'buyerPaymentAccountId': buyerPaymentAccountId.trim(),
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

class TradesQuery {
  final String? status;
  final String? offerId;
  final String? q;
  final int? page;
  final int? limit;

  const TradesQuery({this.status, this.offerId, this.q, this.page, this.limit});

  Map<String, String> toQueryMap() => {
    if (status != null && status!.trim().isNotEmpty) 'status': status!.trim(),
    if (offerId != null && offerId!.trim().isNotEmpty)
      'offerId': offerId!.trim(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}

class CancelTradeRequest {
  final String? reason;

  const CancelTradeRequest({this.reason});

  Map<String, dynamic> toJson() => {
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

class SendTradeMessageRequest {
  final String message;

  const SendTradeMessageRequest({required this.message});

  Map<String, dynamic> toJson() => {'message': message.trim()};
}
