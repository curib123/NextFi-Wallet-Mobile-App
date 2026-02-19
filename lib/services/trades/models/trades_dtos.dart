class CreateTradeRequest {
  final String offerId;
  final double amount;
  final String sellerPaymentAccountId;
  final String? buyerPaymentAccountId;
  final String? buyerWalletId;
  final String? buyerPublicAddress;
  final String idempotencyKey;
  final String? fundTxHash;
  final String? claimableBalanceId;
  final String? note;

  const CreateTradeRequest({
    required this.offerId,
    required this.amount,
    required this.sellerPaymentAccountId,
    this.buyerPaymentAccountId,
    this.buyerWalletId,
    this.buyerPublicAddress,
    required this.idempotencyKey,
    this.fundTxHash,
    this.claimableBalanceId,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId.trim(),
    'amount': amount,
    'sellerPaymentAccountId': sellerPaymentAccountId.trim(),
    if (buyerPaymentAccountId != null &&
        buyerPaymentAccountId!.trim().isNotEmpty)
      'buyerPaymentAccountId': buyerPaymentAccountId!.trim(),
    if (buyerWalletId != null && buyerWalletId!.trim().isNotEmpty)
      'buyerWalletId': buyerWalletId!.trim(),
    if (buyerPublicAddress != null && buyerPublicAddress!.trim().isNotEmpty)
      'buyerPublicAddress': buyerPublicAddress!.trim(),
    'idempotencyKey': idempotencyKey.trim(),
    if (fundTxHash != null && fundTxHash!.trim().isNotEmpty)
      'fundTxHash': fundTxHash!.trim(),
    if (claimableBalanceId != null && claimableBalanceId!.trim().isNotEmpty)
      'claimableBalanceId': claimableBalanceId!.trim(),
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
  final String idempotencyKey;
  final String? txHash;
  final String? reason;

  const CancelTradeRequest({
    required this.idempotencyKey,
    this.txHash,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey.trim(),
    if (txHash != null && txHash!.trim().isNotEmpty) 'txHash': txHash!.trim(),
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

class MarkPaidTradeRequest {
  final String idempotencyKey;

  const MarkPaidTradeRequest({required this.idempotencyKey});

  Map<String, dynamic> toJson() => {'idempotencyKey': idempotencyKey.trim()};
}

class ReleaseTradeRequest {
  final String idempotencyKey;
  final String? txHash;

  const ReleaseTradeRequest({required this.idempotencyKey, this.txHash});

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey.trim(),
    if (txHash != null && txHash!.trim().isNotEmpty) 'txHash': txHash!.trim(),
  };
}

class SendTradeMessageRequest {
  final String message;

  const SendTradeMessageRequest({required this.message});

  Map<String, dynamic> toJson() => {'message': message.trim()};
}
