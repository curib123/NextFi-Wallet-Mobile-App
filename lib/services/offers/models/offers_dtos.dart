enum OfferType { buy, sell }

enum OfferStatus { active, paused, completed, cancelled }

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
  final String? visibleOnly;
  final String? minAmount;
  final String? maxAmount;
  final String? receiverStellarAddress;
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
    this.visibleOnly,
    this.minAmount,
    this.maxAmount,
    this.receiverStellarAddress,
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
    if (visibleOnly != null && visibleOnly!.trim().isNotEmpty)
      'visibleOnly': visibleOnly!.trim(),
    if (minAmount != null && minAmount!.trim().isNotEmpty)
      'minAmount': minAmount!.trim(),
    if (maxAmount != null && maxAmount!.trim().isNotEmpty)
      'maxAmount': maxAmount!.trim(),
    if (receiverStellarAddress != null &&
        receiverStellarAddress!.trim().isNotEmpty)
      'receiverStellarAddress': receiverStellarAddress!.trim(),
    if (page != null && page!.trim().isNotEmpty) 'page': page!.trim(),
    if (limit != null && limit!.trim().isNotEmpty) 'limit': limit!.trim(),
  };
}

class CreateOfferRequest {
  final OfferType type;
  final String asset;
  final String fiatCurrency;
  final String? receiverStellarAddress;
  final num marginPercent;
  final num minAmount;
  final num maxAmount;
  final num? totalQty;
  final num? availableQty;
  final int? paymentWindowMinutes;
  final String? autoReply;
  final bool? isVisible;
  final List<String> paymentMethodIds;

  const CreateOfferRequest({
    required this.type,
    required this.asset,
    required this.fiatCurrency,
    this.receiverStellarAddress,
    required this.marginPercent,
    required this.minAmount,
    required this.maxAmount,
    this.totalQty,
    this.availableQty,
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
    if (methods.isEmpty) {
      throw ArgumentError('paymentMethodIds must not be empty');
    }

    return {
      'type': _offerTypeWire(type),
      'asset': _normalizeUpper(asset),
      'fiatCurrency': _normalizeUpper(fiatCurrency),
      if (_trim(receiverStellarAddress) != null)
        'receiverStellarAddress': _trim(receiverStellarAddress),
      'marginPercent': marginPercent,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      if (totalQty != null) 'totalQty': totalQty,
      if (availableQty != null) 'availableQty': availableQty,
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
  final String? receiverStellarAddress;
  final num? marginPercent;
  final num? minAmount;
  final num? maxAmount;
  final num? totalQty;
  final num? availableQty;
  final int? paymentWindowMinutes;
  final String? autoReply;
  final bool? isVisible;
  final List<String>? paymentMethodIds;

  const UpdateOfferRequest({
    this.type,
    this.asset,
    this.fiatCurrency,
    this.receiverStellarAddress,
    this.marginPercent,
    this.minAmount,
    this.maxAmount,
    this.totalQty,
    this.availableQty,
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
      if (_trim(receiverStellarAddress) != null)
        'receiverStellarAddress': _trim(receiverStellarAddress),
      if (marginPercent != null) 'marginPercent': marginPercent,
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
      if (totalQty != null) 'totalQty': totalQty,
      if (availableQty != null) 'availableQty': availableQty,
      if (paymentWindowMinutes != null)
        'paymentWindowMinutes': paymentWindowMinutes,
      if (_trim(autoReply) != null) 'autoReply': _trim(autoReply),
      if (isVisible != null) 'isVisible': isVisible,
      if (cleanedMethods != null) 'paymentMethodIds': cleanedMethods,
    };
  }
}
