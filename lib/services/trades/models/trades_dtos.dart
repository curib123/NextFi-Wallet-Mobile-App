import 'package:next_fi/services/trades/models/trades_models.dart';

class CreateTradeRequest {
  final String offerId;
  final String sellerPaymentAccountId;
  final String? buyerPaymentAccountId;
  final String cryptoAmount;
  final String fiatAmount;
  final String cryptoReceiverAddress;
  final String? cryptoReceiverMemo;

  const CreateTradeRequest({
    required this.offerId,
    required this.sellerPaymentAccountId,
    this.buyerPaymentAccountId,
    required this.cryptoAmount,
    required this.fiatAmount,
    required this.cryptoReceiverAddress,
    this.cryptoReceiverMemo,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'sellerPaymentAccountId': sellerPaymentAccountId,
    if (buyerPaymentAccountId != null)
      'buyerPaymentAccountId': buyerPaymentAccountId,
    'cryptoAmount': cryptoAmount,
    'fiatAmount': fiatAmount,
    'cryptoReceiverAddress': cryptoReceiverAddress,
    if (cryptoReceiverMemo != null) 'cryptoReceiverMemo': cryptoReceiverMemo,
  };
}

class MarkFiatSentRequest {
  const MarkFiatSentRequest();
  Map<String, dynamic> toJson() => {};
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
