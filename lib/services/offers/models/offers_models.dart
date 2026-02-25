import 'offers_dtos.dart';

OfferType? _readOfferType(dynamic value) {
  final v = value?.toString().trim().toUpperCase();
  if (v == 'BUY') return OfferType.buy;
  if (v == 'SELL') return OfferType.sell;
  return null;
}

OfferStatus? _readOfferStatus(dynamic value) {
  final v = value?.toString().trim().toUpperCase();
  switch (v) {
    case 'ACTIVE':
      return OfferStatus.active;
    case 'PAUSED':
      return OfferStatus.paused;
    case 'COMPLETED':
      return OfferStatus.completed;
    case 'CANCELLED':
      return OfferStatus.cancelled;
    default:
      return null;
  }
}

class OfferModel {
  final String id;
  final OfferType? type;
  final OfferStatus? status;
  final String asset;
  final String fiatCurrency;
  final double? marginPercent;
  final double? successRate;
  final double? marketPrice; // Price in fiat per unit of crypto (e.g., PHP 1.00 per XLM)
  final double? minAmount;
  final double? maxAmount;
  final double? totalQty;
  final double? availableQty;
  final int? paymentWindowMinutes;
  final String? autoReply;
  final bool isVisible;
  final String? sellerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> paymentMethodIds;
  final List<Map<String, dynamic>> paymentMethods;
  final Map<String, dynamic>? seller;

  const OfferModel({
    required this.id,
    this.type,
    this.status,
    required this.asset,
    required this.fiatCurrency,
    this.marginPercent,
    this.successRate,
    this.marketPrice,
    this.minAmount,
    this.maxAmount,
    this.totalQty,
    this.availableQty,
    this.paymentWindowMinutes,
    this.autoReply,
    this.isVisible = false,
    this.sellerId,
    this.createdAt,
    this.updatedAt,
    this.paymentMethodIds = const [],
    this.paymentMethods = const [],
    this.seller,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    double? readDouble(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    int? readInt(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v == 'true' || v == '1') return true;
          if (v == 'false' || v == '0') return false;
        }
      }
      return fallback;
    }

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    List<String> readPaymentMethodIds() {
      final raw = json['paymentMethodIds'];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }

      final links = json['offerPaymentMethods'];
      if (links is List) {
        final ids = <String>[];
        for (final link in links) {
          if (link is! Map<String, dynamic>) continue;
          final id = (link['paymentMethodId'] ?? link['payment_method_id'])
              ?.toString()
              .trim();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        return ids;
      }

      return const [];
    }

    List<Map<String, dynamic>> readPaymentMethods() {
      final raw = json['paymentMethods'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    }

    final sellerRaw = json['seller'];

    return OfferModel(
      id: readString(const ['id']),
      type: _readOfferType(json['type']),
      status: _readOfferStatus(json['status']),
      asset: readString(const ['asset']),
      fiatCurrency: readString(const ['fiatCurrency', 'fiat_currency']),
      marginPercent: readDouble(const ['marginPercent', 'margin_percent']),
      successRate: readDouble(const ['successRate', 'success_rate']),
      marketPrice: readDouble(const ['marketPrice', 'market_price', 'price']),
      minAmount: readDouble(const ['minAmount', 'min_amount']),
      maxAmount: readDouble(const ['maxAmount', 'max_amount']),
      totalQty: readDouble(const ['totalQty', 'total_qty']),
      availableQty: readDouble(const ['availableQty', 'available_qty']),
      paymentWindowMinutes: readInt(const [
        'paymentWindowMinutes',
        'payment_window_minutes',
      ]),
      autoReply: (() {
        final text = readString(const ['autoReply', 'auto_reply']);
        return text.isEmpty ? null : text;
      })(),
      isVisible: readBool(const ['isVisible', 'is_visible']),
      sellerId: (() {
        final text = readString(const ['sellerId', 'seller_id']);
        return text.isEmpty ? null : text;
      })(),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
      paymentMethodIds: readPaymentMethodIds(),
      paymentMethods: readPaymentMethods(),
      seller: sellerRaw is Map<String, dynamic> ? sellerRaw : null,
    );
  }
}

class OffersMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const OffersMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory OffersMeta.fromJson(Map<String, dynamic> json) {
    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final v = json[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return fallback;
    }

    return OffersMeta(
      total: readInt(const ['total', 'count']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit', 'pageSize', 'page_size'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class OffersPagedResponse {
  final List<OfferModel> items;
  final OffersMeta meta;

  const OffersPagedResponse({required this.items, required this.meta});
}
