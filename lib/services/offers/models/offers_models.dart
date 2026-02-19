import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

enum OfferType { buy, sell, unknown }

enum OfferAsset { xlm, usdc, unknown }

enum OfferPriceType { fixed, floating, unknown }

OfferType offerTypeFromApi(dynamic raw) {
  final v = raw?.toString().trim().toUpperCase();
  switch (v) {
    case 'BUY':
      return OfferType.buy;
    case 'SELL':
      return OfferType.sell;
    default:
      return OfferType.unknown;
  }
}

String offerTypeToApi(OfferType type) {
  switch (type) {
    case OfferType.buy:
      return 'BUY';
    case OfferType.sell:
      return 'SELL';
    case OfferType.unknown:
      return 'SELL';
  }
}

OfferAsset offerAssetFromApi(dynamic raw) {
  final v = raw?.toString().trim().toUpperCase();
  switch (v) {
    case 'XLM':
      return OfferAsset.xlm;
    case 'USDC':
      return OfferAsset.usdc;
    default:
      return OfferAsset.unknown;
  }
}

String offerAssetToApi(OfferAsset asset) {
  switch (asset) {
    case OfferAsset.xlm:
      return 'XLM';
    case OfferAsset.usdc:
      return 'USDC';
    case OfferAsset.unknown:
      return 'USDC';
  }
}

OfferPriceType offerPriceTypeFromApi(dynamic raw) {
  final v = raw?.toString().trim().toUpperCase();
  switch (v) {
    case 'FIXED':
      return OfferPriceType.fixed;
    case 'FLOATING':
      return OfferPriceType.floating;
    default:
      return OfferPriceType.unknown;
  }
}

String offerPriceTypeToApi(OfferPriceType type) {
  switch (type) {
    case OfferPriceType.fixed:
      return 'FIXED';
    case OfferPriceType.floating:
      return 'FLOATING';
    case OfferPriceType.unknown:
      return 'FIXED';
  }
}

class OfferPaymentMethodRef {
  final String id;
  final String code;
  final String name;

  const OfferPaymentMethodRef({
    required this.id,
    required this.code,
    required this.name,
  });

  factory OfferPaymentMethodRef.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final k in keys) {
        final value = json[k];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    return OfferPaymentMethodRef(
      id: readString(const ['id', 'paymentMethodId', 'payment_method_id']),
      code: readString(const ['code']),
      name: readString(const ['name']),
    );
  }
}

class OfferWalletRef {
  final String id;
  final String publicAddress;
  final String network;
  final String? label;

  const OfferWalletRef({
    required this.id,
    required this.publicAddress,
    required this.network,
    this.label,
  });

  factory OfferWalletRef.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    return OfferWalletRef(
      id: readString(const ['id', 'walletId', 'wallet_id']),
      publicAddress: readString(const [
        'publicAddress',
        'public_address',
        'address',
      ]),
      network: readString(const ['network'], fallback: 'stellar'),
      label: (() {
        final text = readString(const ['label']);
        return text.isEmpty ? null : text;
      })(),
    );
  }
}

class OfferModel {
  final String id;
  final String? merchantUserId;
  final String? sellerWalletId;
  final OfferWalletRef? sellerWallet;
  final OfferType type;
  final OfferAsset asset;
  final String fiatCurrency;
  final OfferPriceType priceType;
  final double? fixedPrice;
  final double? marginPercent;
  final double minAmount;
  final double maxAmount;
  final double? totalQty;
  final double? remainingQty;
  final int paymentWindow;
  final bool requiredReady;
  final bool isActive;
  final String? autoReply;
  final List<OfferPaymentMethodRef> paymentMethods;
  final List<UserPaymentAccountModel> sellerPaymentAccounts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfferModel({
    required this.id,
    this.merchantUserId,
    this.sellerWalletId,
    this.sellerWallet,
    this.type = OfferType.unknown,
    this.asset = OfferAsset.unknown,
    this.fiatCurrency = '',
    this.priceType = OfferPriceType.unknown,
    this.fixedPrice,
    this.marginPercent,
    this.minAmount = 0,
    this.maxAmount = 0,
    this.totalQty,
    this.remainingQty,
    this.paymentWindow = 15,
    this.requiredReady = true,
    this.isActive = true,
    this.autoReply,
    this.paymentMethods = const [],
    this.sellerPaymentAccounts = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') return true;
          if (normalized == 'false' || normalized == '0') return false;
        }
      }
      return fallback;
    }

    double readDouble(List<String> keys, {double fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    double? readNullableDouble(List<String> keys) {
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

    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    List<OfferPaymentMethodRef> readPaymentMethods() {
      final candidates = [
        json['paymentMethods'],
        json['payment_methods'],
        json['methods'],
      ];

      for (final raw in candidates) {
        if (raw is! List) continue;
        return raw
            .whereType<Map<String, dynamic>>()
            .map(OfferPaymentMethodRef.fromJson)
            .toList();
      }

      return const [];
    }

    List<UserPaymentAccountModel> readSellerAccounts() {
      final candidates = [
        json['sellerPaymentAccounts'],
        json['seller_payment_accounts'],
        json['paymentAccounts'],
        json['payment_accounts'],
        json['accounts'],
      ];
      for (final raw in candidates) {
        if (raw is! List) continue;
        return raw
            .whereType<Map<String, dynamic>>()
            .map(UserPaymentAccountModel.fromJson)
            .toList();
      }
      return const [];
    }

    OfferWalletRef? readSellerWallet() {
      final candidates = [
        json['sellerWallet'],
        json['seller_wallet'],
        json['wallet'],
      ];
      for (final raw in candidates) {
        if (raw is! Map<String, dynamic>) continue;
        final wallet = OfferWalletRef.fromJson(raw);
        if (wallet.id.isNotEmpty || wallet.publicAddress.isNotEmpty) {
          return wallet;
        }
      }
      return null;
    }

    final sellerWallet = readSellerWallet();

    return OfferModel(
      id: readString(const ['id']),
      merchantUserId: (() {
        final userId = readString(const [
          'merchantUserId',
          'merchant_user_id',
          'userId',
          'user_id',
        ]);
        return userId.isEmpty ? null : userId;
      })(),
      sellerWalletId: (() {
        final walletId = readString(const [
          'sellerWalletId',
          'seller_wallet_id',
          'walletId',
          'wallet_id',
        ]);
        if (walletId.isNotEmpty) return walletId;
        final nested = sellerWallet?.id.trim() ?? '';
        return nested.isEmpty ? null : nested;
      })(),
      sellerWallet: sellerWallet,
      type: offerTypeFromApi(json['type']),
      asset: offerAssetFromApi(json['asset']),
      fiatCurrency: readString(const [
        'fiatCurrency',
        'fiat_currency',
      ], fallback: 'PHP'),
      priceType: offerPriceTypeFromApi(json['priceType'] ?? json['price_type']),
      fixedPrice: readNullableDouble(const ['fixedPrice', 'fixed_price']),
      marginPercent: readNullableDouble(const [
        'marginPercent',
        'margin_percent',
      ]),
      minAmount: readDouble(const ['minAmount', 'min_amount']),
      maxAmount: readDouble(const ['maxAmount', 'max_amount']),
      totalQty: readNullableDouble(const ['totalQty', 'total_qty']),
      remainingQty: readNullableDouble(const ['remainingQty', 'remaining_qty']),
      paymentWindow: readInt(const [
        'paymentWindow',
        'payment_window',
      ], fallback: 15),
      requiredReady: readBool(const [
        'requiredReady',
        'required_ready',
      ], fallback: true),
      isActive: readBool(const ['isActive', 'is_active'], fallback: true),
      autoReply: (() {
        final text = readString(const ['autoReply', 'auto_reply']);
        return text.isEmpty ? null : text;
      })(),
      paymentMethods: readPaymentMethods(),
      sellerPaymentAccounts: readSellerAccounts(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}
