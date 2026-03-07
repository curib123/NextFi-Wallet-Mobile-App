enum OfferType { buy, sell }

enum OfferStatus { active, paused, completed, cancelled }

enum OfferLimitType { fiat, asset }

enum OfferSortBy {
  best,
  newest,
  oldest,
  successRate,
  minAmount,
  maxAmount,
  marginPercent,
}

enum OfferSortOrder { asc, desc }

String _normalizeUpper(String value) => value.trim().toUpperCase();

String _offerTypeWire(OfferType value) =>
    value == OfferType.buy ? 'BUY' : 'SELL';

String _offerStatusWire(OfferStatus value) {
  switch (value) {
    case OfferStatus.active:
      return 'ACTIVE';
    case OfferStatus.paused:
      return 'PAUSED';
    case OfferStatus.completed:
      return 'COMPLETED';
    case OfferStatus.cancelled:
      return 'CANCELLED';
  }
}

String _offerLimitTypeWire(OfferLimitType value) =>
    value == OfferLimitType.asset ? 'ASSET' : 'FIAT';

String _offerSortByWire(OfferSortBy value) {
  switch (value) {
    case OfferSortBy.best:
      return 'best';
    case OfferSortBy.newest:
      return 'newest';
    case OfferSortBy.oldest:
      return 'oldest';
    case OfferSortBy.successRate:
      return 'successRate';
    case OfferSortBy.minAmount:
      return 'minAmount';
    case OfferSortBy.maxAmount:
      return 'maxAmount';
    case OfferSortBy.marginPercent:
      return 'marginPercent';
  }
}

String _offerSortOrderWire(OfferSortOrder value) =>
    value == OfferSortOrder.asc ? 'asc' : 'desc';

List<String> _cleanPaymentMethodIds(List<String> ids) {
  final seen = <String>{};
  final cleaned = <String>[];
  for (final id in ids) {
    final value = id.trim();
    if (value.isEmpty || seen.contains(value)) continue;
    seen.add(value);
    cleaned.add(value);
  }
  return cleaned;
}

/// Shared filters for /offers, /offers/me and /offers/admin/list.
class OffersListQuery {
  final String? q;
  final OfferType? type;
  final OfferStatus? status;
  final String? asset;
  final String? fiatCurrency;
  final String? sellerId;
  final String? paymentMethodId;
  final String? amount;
  final String? visibleOnly;
  final String? minAmount;
  final String? maxAmount;
  final OfferLimitType? limitType;
  final String? receiverStellarAddress;
  final OfferSortBy? sortBy;
  final OfferSortOrder? sortOrder;
  final String? page;
  final String? limit;

  const OffersListQuery({
    this.q,
    this.type,
    this.status,
    this.asset,
    this.fiatCurrency,
    this.sellerId,
    this.paymentMethodId,
    this.amount,
    this.visibleOnly,
    this.minAmount,
    this.maxAmount,
    this.limitType,
    this.receiverStellarAddress,
    this.sortBy,
    this.sortOrder,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryMap() => {
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (type != null) 'type': _offerTypeWire(type!),
    if (status != null) 'status': _offerStatusWire(status!),
    if (asset != null && asset!.trim().isNotEmpty) 'asset': _normalizeUpper(asset!),
    if (fiatCurrency != null && fiatCurrency!.trim().isNotEmpty)
      'fiatCurrency': _normalizeUpper(fiatCurrency!),
    if (sellerId != null && sellerId!.trim().isNotEmpty) 'sellerId': sellerId!.trim(),
    if (paymentMethodId != null && paymentMethodId!.trim().isNotEmpty)
      'paymentMethodId': paymentMethodId!.trim(),
    if (amount != null && amount!.trim().isNotEmpty) 'amount': amount!.trim(),
    if (visibleOnly != null && visibleOnly!.trim().isNotEmpty)
      'visibleOnly': visibleOnly!.trim(),
    if (minAmount != null && minAmount!.trim().isNotEmpty)
      'minAmount': minAmount!.trim(),
    if (maxAmount != null && maxAmount!.trim().isNotEmpty)
      'maxAmount': maxAmount!.trim(),
    if (limitType != null) 'limitType': _offerLimitTypeWire(limitType!),
    if (receiverStellarAddress != null &&
        receiverStellarAddress!.trim().isNotEmpty)
      'receiverStellarAddress': receiverStellarAddress!.trim(),
    if (sortBy != null) 'sortBy': _offerSortByWire(sortBy!),
    if (sortOrder != null) 'sortOrder': _offerSortOrderWire(sortOrder!),
    if (page != null && page!.trim().isNotEmpty) 'page': page!.trim(),
    if (limit != null && limit!.trim().isNotEmpty) 'limit': limit!.trim(),
  };
}

class CreateOfferRequest {
  final OfferType type;
  final String asset;
  final String fiatCurrency;
  final String receiverStellarAddress;
  final num marginPercent;
  final OfferLimitType limitType;
  final num minAmount;
  final num maxAmount;
  final int? paymentWindowMinutes;
  final String? autoReply;
  final bool? isVisible;
  final List<String> paymentMethodIds;

  const CreateOfferRequest({
    required this.type,
    required this.asset,
    required this.fiatCurrency,
    required this.receiverStellarAddress,
    required this.marginPercent,
    required this.limitType,
    required this.minAmount,
    required this.maxAmount,
    this.paymentWindowMinutes,
    this.autoReply,
    this.isVisible,
    required this.paymentMethodIds,
  });

  String? _trim(String? value) {
    if (value == null) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> toJson() {
    final methods = _cleanPaymentMethodIds(paymentMethodIds);
    final receiver = _trim(receiverStellarAddress);
    if (methods.isEmpty) {
      throw ArgumentError('paymentMethodIds must not be empty');
    }
    if (receiver == null) {
      throw ArgumentError('receiverStellarAddress must not be empty');
    }

    return {
      'type': _offerTypeWire(type),
      'asset': _normalizeUpper(asset),
      'fiatCurrency': _normalizeUpper(fiatCurrency),
      'receiverStellarAddress': receiver,
      'marginPercent': marginPercent,
      'limitType': _offerLimitTypeWire(limitType),
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      if (paymentWindowMinutes != null)
        'paymentWindowMinutes': paymentWindowMinutes,
      if (_trim(autoReply) != null) 'autoReply': _trim(autoReply),
      if (isVisible != null) 'isVisible': isVisible,
      'paymentMethodIds': methods,
    };
  }
}

class UpdateOfferRequest {
  final OfferType? type;
  final String? asset;
  final String? fiatCurrency;
  final OfferLimitType? limitType;
  final String? receiverStellarAddress;
  final num? marginPercent;
  final num? minAmount;
  final num? maxAmount;
  final int? paymentWindowMinutes;
  final String? autoReply;
  final bool? isVisible;
  final List<String>? paymentMethodIds;

  const UpdateOfferRequest({
    this.type,
    this.asset,
    this.fiatCurrency,
    this.limitType,
    this.receiverStellarAddress,
    this.marginPercent,
    this.minAmount,
    this.maxAmount,
    this.paymentWindowMinutes,
    this.autoReply,
    this.isVisible,
    this.paymentMethodIds,
  });

  String? _trim(String? value) {
    if (value == null) return null;
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> toJson() {
    final cleanedMethods = paymentMethodIds == null
        ? null
        : _cleanPaymentMethodIds(paymentMethodIds!);
    if (paymentMethodIds != null && cleanedMethods!.isEmpty) {
      throw ArgumentError('paymentMethodIds must not be empty when provided');
    }

    return {
      if (type != null) 'type': _offerTypeWire(type!),
      if (_trim(asset) != null) 'asset': _normalizeUpper(asset!),
      if (_trim(fiatCurrency) != null)
        'fiatCurrency': _normalizeUpper(fiatCurrency!),
      if (limitType != null) 'limitType': _offerLimitTypeWire(limitType!),
      if (_trim(receiverStellarAddress) != null)
        'receiverStellarAddress': _trim(receiverStellarAddress),
      if (marginPercent != null) 'marginPercent': marginPercent,
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
      if (paymentWindowMinutes != null)
        'paymentWindowMinutes': paymentWindowMinutes,
      if (_trim(autoReply) != null) 'autoReply': _trim(autoReply),
      if (isVisible != null) 'isVisible': isVisible,
      if (cleanedMethods != null) 'paymentMethodIds': cleanedMethods,
    };
  }
}
