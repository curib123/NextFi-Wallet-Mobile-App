enum TradeStatus {
  pending,
  escrowFunded,
  fiatSent,
  completed,
  cancelled,
  disputed,
  unknown;

  static TradeStatus fromString(String? v) {
    switch (v?.toUpperCase().replaceAll('_', '').replaceAll('-', '')) {
      case 'PENDING':
        return TradeStatus.pending;
      case 'ESCROWFUNDED':
      case 'ACTIVE':
      case 'FUNDED':
        return TradeStatus.escrowFunded;
      case 'FIATSENT':
      case 'PAYMENTPENDING':
      case 'PAYMENTSENT':
        return TradeStatus.fiatSent;
      case 'COMPLETED':
      case 'RELEASED':
        return TradeStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
        return TradeStatus.cancelled;
      case 'DISPUTED':
        return TradeStatus.disputed;
      default:
        return TradeStatus.unknown;
    }
  }

  bool get isActive =>
      this == TradeStatus.pending ||
      this == TradeStatus.escrowFunded ||
      this == TradeStatus.fiatSent ||
      this == TradeStatus.disputed;

  bool get isTerminal =>
      this == TradeStatus.completed || this == TradeStatus.cancelled;
}

class TradeEscrowModel {
  final String id;
  final String? claimableBalanceId;
  final String? status;
  final String? txHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TradeEscrowModel({
    required this.id,
    this.claimableBalanceId,
    this.status,
    this.txHash,
    this.createdAt,
    this.updatedAt,
  });

  factory TradeEscrowModel.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return TradeEscrowModel(
      id: json['id']?.toString() ?? '',
      claimableBalanceId: json['claimableBalanceId']?.toString() ??
          json['claimable_balance_id']?.toString(),
      status: json['status']?.toString(),
      txHash: json['txHash']?.toString() ?? json['tx_hash']?.toString(),
      createdAt: readDate(json['createdAt'] ?? json['created_at']),
      updatedAt: readDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class TradeModel {
  final String id;
  final String offerId;
  final TradeStatus status;
  final String asset;
  final String fiatCurrency;
  final double cryptoAmount;
  final double fiatAmount;
  final String buyerId;
  final String sellerId;
  final String cryptoReceiverAddress;
  final String? cryptoReceiverMemo;
  final String sellerPaymentAccountId;
  final String? buyerPaymentAccountId;
  final int? paymentWindowMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final TradeEscrowModel? escrow;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? sellerPaymentAccount;

  const TradeModel({
    required this.id,
    required this.offerId,
    required this.status,
    required this.asset,
    required this.fiatCurrency,
    required this.cryptoAmount,
    required this.fiatAmount,
    required this.buyerId,
    required this.sellerId,
    required this.cryptoReceiverAddress,
    this.cryptoReceiverMemo,
    required this.sellerPaymentAccountId,
    this.buyerPaymentAccountId,
    this.paymentWindowMinutes,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.escrow,
    this.offer,
    this.sellerPaymentAccount,
  });

  factory TradeModel.fromJson(Map<String, dynamic> json) {
    double readDouble(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final p = double.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return 0.0;
    }

    int? readInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return null;
    }

    String readStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        final t = v.toString().trim();
        if (t.isNotEmpty) return t;
      }
      return '';
    }

    DateTime? readDate(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        final d = DateTime.tryParse(v.toString());
        if (d != null) return d;
      }
      return null;
    }

    final escrowRaw = json['escrow'] ?? json['tradeEscrow'];
    final offerRaw = json['offer'];
    final spaRaw = json['sellerPaymentAccount'];

    return TradeModel(
      id: readStr(const ['id']),
      offerId: readStr(const ['offerId', 'offer_id']),
      status: TradeStatus.fromString(json['status']?.toString()),
      asset: readStr(const ['asset']),
      fiatCurrency: readStr(const ['fiatCurrency', 'fiat_currency']),
      cryptoAmount: readDouble(const ['cryptoAmount', 'crypto_amount']),
      fiatAmount: readDouble(const ['fiatAmount', 'fiat_amount']),
      buyerId: readStr(const ['buyerId', 'buyer_id']),
      sellerId: readStr(const ['sellerId', 'seller_id']),
      cryptoReceiverAddress: readStr(
        const ['cryptoReceiverAddress', 'crypto_receiver_address'],
      ),
      cryptoReceiverMemo: (() {
        final v = readStr(const [
          'cryptoReceiverMemo',
          'crypto_receiver_memo',
        ]);
        return v.isEmpty ? null : v;
      })(),
      sellerPaymentAccountId: readStr(
        const ['sellerPaymentAccountId', 'seller_payment_account_id'],
      ),
      buyerPaymentAccountId: (() {
        final v = readStr(const [
          'buyerPaymentAccountId',
          'buyer_payment_account_id',
        ]);
        return v.isEmpty ? null : v;
      })(),
      paymentWindowMinutes: readInt(const [
        'paymentWindowMinutes',
        'payment_window_minutes',
      ]),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
      expiresAt: readDate(const ['expiresAt', 'expires_at', 'paymentDeadline',
        'payment_deadline']),
      escrow: escrowRaw is Map<String, dynamic>
          ? TradeEscrowModel.fromJson(escrowRaw)
          : null,
      offer: offerRaw is Map<String, dynamic> ? offerRaw : null,
      sellerPaymentAccount:
          spaRaw is Map<String, dynamic> ? spaRaw : null,
    );
  }

  TradeModel copyWith({TradeStatus? status, TradeEscrowModel? escrow}) {
    return TradeModel(
      id: id,
      offerId: offerId,
      status: status ?? this.status,
      asset: asset,
      fiatCurrency: fiatCurrency,
      cryptoAmount: cryptoAmount,
      fiatAmount: fiatAmount,
      buyerId: buyerId,
      sellerId: sellerId,
      cryptoReceiverAddress: cryptoReceiverAddress,
      cryptoReceiverMemo: cryptoReceiverMemo,
      sellerPaymentAccountId: sellerPaymentAccountId,
      buyerPaymentAccountId: buyerPaymentAccountId,
      paymentWindowMinutes: paymentWindowMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      escrow: escrow ?? this.escrow,
      offer: offer,
      sellerPaymentAccount: sellerPaymentAccount,
    );
  }
}

class TradesPagedMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const TradesPagedMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory TradesPagedMeta.fromJson(Map<String, dynamic> json) {
    int ri(List<String> keys, {int fallback = 0}) {
      for (final k in keys) {
        final v = json[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return fallback;
    }

    return TradesPagedMeta(
      total: ri(const ['total', 'count']),
      page: ri(const ['page'], fallback: 1),
      limit: ri(const ['limit', 'pageSize'], fallback: 20),
      totalPages: ri(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class TradesPagedResponse {
  final List<TradeModel> items;
  final TradesPagedMeta meta;

  const TradesPagedResponse({required this.items, required this.meta});
}
