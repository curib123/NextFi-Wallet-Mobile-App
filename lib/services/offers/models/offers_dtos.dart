import 'offers_models.dart';

class OffersQuery {
  final OfferType? type;
  final OfferAsset? asset;
  final String? fiatCurrency;
  final String? q;
  final int? page;
  final int? limit;

  const OffersQuery({
    this.type,
    this.asset,
    this.fiatCurrency,
    this.q,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryMap() => {
    if (type != null && type != OfferType.unknown)
      'type': offerTypeToApi(type!),
    if (asset != null && asset != OfferAsset.unknown)
      'asset': offerAssetToApi(asset!),
    if (fiatCurrency != null && fiatCurrency!.trim().isNotEmpty)
      'fiatCurrency': fiatCurrency!.trim().toUpperCase(),
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    if (page != null && page! > 0) 'page': page!.toString(),
    if (limit != null && limit! > 0) 'limit': limit!.toString(),
  };
}

class CreateOfferRequest {
  final OfferType type;
  final OfferAsset asset;
  final String fiatCurrency;
  final OfferPriceType priceType;
  final double? fixedPrice;
  final double? marginPercent;
  final double minAmount;
  final double maxAmount;
  final double totalQty;
  final int paymentWindow;
  final bool requiredReady;
  final List<String> paymentMethodIds;
  final String? autoReply;

  const CreateOfferRequest({
    required this.type,
    required this.asset,
    required this.fiatCurrency,
    required this.priceType,
    this.fixedPrice,
    this.marginPercent,
    required this.minAmount,
    required this.maxAmount,
    required this.totalQty,
    required this.paymentWindow,
    required this.requiredReady,
    required this.paymentMethodIds,
    this.autoReply,
  });

  Map<String, dynamic> toJson() => {
    'type': offerTypeToApi(type),
    'asset': offerAssetToApi(asset),
    'fiatCurrency': fiatCurrency.trim().toUpperCase(),
    'priceType': offerPriceTypeToApi(priceType),
    if (fixedPrice != null) 'fixedPrice': fixedPrice,
    if (marginPercent != null) 'marginPercent': marginPercent,
    'minAmount': minAmount,
    'maxAmount': maxAmount,
    'totalQty': totalQty,
    'paymentWindow': paymentWindow,
    'requiredReady': requiredReady,
    'paymentMethodIds': paymentMethodIds,
    if (autoReply != null && autoReply!.trim().isNotEmpty)
      'autoReply': autoReply!.trim(),
  };
}

class UpdateOfferRequest {
  final OfferPriceType? priceType;
  final double? fixedPrice;
  final double? marginPercent;
  final double? minAmount;
  final double? maxAmount;
  final double? totalQty;
  final int? paymentWindow;
  final bool? requiredReady;
  final bool? isActive;
  final List<String>? paymentMethodIds;
  final String? autoReply;

  const UpdateOfferRequest({
    this.priceType,
    this.fixedPrice,
    this.marginPercent,
    this.minAmount,
    this.maxAmount,
    this.totalQty,
    this.paymentWindow,
    this.requiredReady,
    this.isActive,
    this.paymentMethodIds,
    this.autoReply,
  });

  Map<String, dynamic> toJson() => {
    if (priceType != null && priceType != OfferPriceType.unknown)
      'priceType': offerPriceTypeToApi(priceType!),
    if (fixedPrice != null) 'fixedPrice': fixedPrice,
    if (marginPercent != null) 'marginPercent': marginPercent,
    if (minAmount != null) 'minAmount': minAmount,
    if (maxAmount != null) 'maxAmount': maxAmount,
    if (totalQty != null) 'totalQty': totalQty,
    if (paymentWindow != null) 'paymentWindow': paymentWindow,
    if (requiredReady != null) 'requiredReady': requiredReady,
    if (isActive != null) 'isActive': isActive,
    if (paymentMethodIds != null) 'paymentMethodIds': paymentMethodIds,
    if (autoReply != null) 'autoReply': autoReply,
  };
}
