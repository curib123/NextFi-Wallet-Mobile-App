import 'package:next_fi/services/trades/models/trades_models.dart';

class CreateTradeRequest {
  final String offerId;
  final String paymentMethodId; // UUID, from offer's paymentMethods
  final String? buyerPaymentAccountId;
  final String cryptoAmount;
  final String fiatAmount;
  final String cryptoReceiverAddress;
  final String? cryptoReceiverMemo;

  const CreateTradeRequest({
    required this.offerId,
    required this.paymentMethodId,
    this.buyerPaymentAccountId,
    required this.cryptoAmount,
    required this.fiatAmount,
    required this.cryptoReceiverAddress,
    this.cryptoReceiverMemo,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'paymentMethodId': paymentMethodId,
    if (buyerPaymentAccountId != null)
      'buyerPaymentAccountId': buyerPaymentAccountId,
    'cryptoAmount': cryptoAmount,
    'fiatAmount': fiatAmount,
    'cryptoReceiverAddress': cryptoReceiverAddress,
    if (cryptoReceiverMemo != null) 'cryptoReceiverMemo': cryptoReceiverMemo,
  };
}

class MarkFiatSentRequest {
  final String? note;
  final List<String>? proofUrls;

  const MarkFiatSentRequest({this.note, this.proofUrls});

  Map<String, dynamic> toJson() => {
    if (note != null && note!.isNotEmpty) 'note': note,
    if (proofUrls != null && proofUrls!.isNotEmpty) 'proofUrls': proofUrls,
  };
}

class ConfirmFiatRequest {
  final String? fiatRefNo;

  const ConfirmFiatRequest({this.fiatRefNo});

  Map<String, dynamic> toJson() => {
    if (fiatRefNo != null && fiatRefNo!.isNotEmpty) 'fiatRefNo': fiatRefNo,
  };
}

class CancelTradeRequest {
  final String? reason;

  const CancelTradeRequest({this.reason});

  Map<String, dynamic> toJson() => {
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };
}

class TradesListQuery {
  final String? q;
  final TradeStatus? status;
  final String? role;
  final String? asset;
  final String? fiatCurrency;
  final int? page;
  final int? limit;

  const TradesListQuery({
    this.q,
    this.status,
    this.role,
    this.asset,
    this.fiatCurrency,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryMap() => {
    if (q != null && q!.isNotEmpty) 'q': q!,
    if (status != null) 'status': status!.name.toUpperCase(),
    if (role != null) 'role': role!,
    if (asset != null && asset!.isNotEmpty) 'asset': asset!,
    if (fiatCurrency != null && fiatCurrency!.isNotEmpty)
      'fiatCurrency': fiatCurrency!,
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}

/// Request to lock crypto into escrow (Step B in both flows)
class LockCryptoRequest {
  final String claimableBalanceId;
  final String createTxHash;

  const LockCryptoRequest({
    required this.claimableBalanceId,
    required this.createTxHash,
  });

  Map<String, dynamic> toJson() => {
    'claimableBalanceId': claimableBalanceId,
    'createTxHash': createTxHash,
  };
}

/// Request to claim crypto from escrow (Step E in both flows)
class ClaimCryptoRequest {
  final String claimTxHash;

  const ClaimCryptoRequest({required this.claimTxHash});

  Map<String, dynamic> toJson() => {'claimTxHash': claimTxHash};
}

/// Request to refund crypto from expired escrow
class RefundCryptoRequest {
  final String refundTxHash;

  const RefundCryptoRequest({required this.refundTxHash});

  Map<String, dynamic> toJson() => {'refundTxHash': refundTxHash};
}

/// Request to upload payment proof
class UploadPaymentProofRequest {
  final String tradeId;
  final String type; // 'FIAT' or 'CRYPTO'
  final String? note;
  final String? referenceNo;
  final String? txHash;

  const UploadPaymentProofRequest({
    required this.tradeId,
    required this.type,
    this.note,
    this.referenceNo,
    this.txHash,
  });

  Map<String, dynamic> toJson() => {
    'tradeId': tradeId,
    'type': type,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (referenceNo != null && referenceNo!.isNotEmpty)
      'referenceNo': referenceNo,
    if (txHash != null && txHash!.isNotEmpty) 'txHash': txHash,
  };
}

/// Request to open a dispute
class OpenDisputeRequest {
  final String tradeId;
  final String reason;
  final String? description;
  final List<String>? evidenceUrls;

  const OpenDisputeRequest({
    required this.tradeId,
    required this.reason,
    this.description,
    this.evidenceUrls,
  });

  Map<String, dynamic> toJson() => {
    'tradeId': tradeId,
    'reason': reason,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (evidenceUrls != null && evidenceUrls!.isNotEmpty)
      'evidenceUrls': evidenceUrls,
  };
}
