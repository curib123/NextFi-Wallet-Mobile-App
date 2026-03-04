enum TradeStatus {
  created,
  cryptoLocked,
  fiatSent,
  fiatConfirmed,
  completed,
  cancelled,
  disputed,
  expired,
  unknown;

  static TradeStatus fromString(String? v) {
    switch (v?.toUpperCase().replaceAll('_', '').replaceAll('-', '')) {
      case 'CREATED':
        return TradeStatus.created;
      case 'CRYPTOLOCKED':
      case 'ESCROWFUNDED':
      case 'ACTIVE':
      case 'FUNDED':
        return TradeStatus.cryptoLocked;
      case 'FIATSENT':
      case 'PAYMENTPENDING':
      case 'PAYMENTSENT':
        return TradeStatus.fiatSent;
      case 'FIATCONFIRMED':
      case 'PAYMENTRECEIVED':
        return TradeStatus.fiatConfirmed;
      case 'COMPLETED':
      case 'RELEASED':
        return TradeStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
        return TradeStatus.cancelled;
      case 'DISPUTED':
        return TradeStatus.disputed;
      case 'EXPIRED':
        return TradeStatus.expired;
      default:
        return TradeStatus.unknown;
    }
  }

  /// Returns a user-friendly label for this status
  String get label {
    switch (this) {
      case TradeStatus.created:
        return 'Waiting for Escrow';
      case TradeStatus.cryptoLocked:
        return 'Ready to Pay';
      case TradeStatus.fiatSent:
        return 'Payment Sent';
      case TradeStatus.fiatConfirmed:
        return 'Payment Confirmed';
      case TradeStatus.completed:
        return 'Trade Completed';
      case TradeStatus.cancelled:
        return 'Trade Cancelled';
      case TradeStatus.disputed:
        return 'Under Dispute';
      case TradeStatus.expired:
        return 'Trade Expired';
      case TradeStatus.unknown:
        return 'Unknown Status';
    }
  }

  /// Returns the icon for this status
  String get iconName {
    switch (this) {
      case TradeStatus.created:
        return 'hourglass_empty';
      case TradeStatus.cryptoLocked:
        return 'lock_clock';
      case TradeStatus.fiatSent:
        return 'pending';
      case TradeStatus.fiatConfirmed:
        return 'check_circle';
      case TradeStatus.completed:
        return 'check_circle';
      case TradeStatus.cancelled:
        return 'cancel';
      case TradeStatus.disputed:
        return 'report';
      case TradeStatus.expired:
        return 'schedule';
      case TradeStatus.unknown:
        return 'help';
    }
  }

  bool get isActive =>
      this == TradeStatus.created ||
      this == TradeStatus.cryptoLocked ||
      this == TradeStatus.fiatSent ||
      this == TradeStatus.fiatConfirmed ||
      this == TradeStatus.disputed;

  bool get isTerminal =>
      this == TradeStatus.completed ||
      this == TradeStatus.cancelled ||
      this == TradeStatus.expired;
}

/// Status of the Claimable Balance escrow
enum EscrowStatus {
  pending,
  cbCreated,
  cbClaimed,
  cbRefunded,
  failed,
  unknown;

  static EscrowStatus fromString(String? v) {
    switch (v?.toUpperCase().replaceAll('_', '').replaceAll('-', '')) {
      case 'PENDING':
        return EscrowStatus.pending;
      case 'CBCREATED':
      case 'ESCROWFUNDED':
      case 'FUNDED':
      case 'ACTIVE':
        return EscrowStatus.cbCreated;
      case 'CBCLAIMED':
      case 'RELEASED':
        return EscrowStatus.cbClaimed;
      case 'CBREFUNDED':
      case 'REFUNDED':
        return EscrowStatus.cbRefunded;
      case 'FAILED':
        return EscrowStatus.failed;
      default:
        return EscrowStatus.unknown;
    }
  }

  bool get isActive => this == EscrowStatus.cbCreated;
}

class TradeEscrowModel {
  final String id;
  final String? claimableBalanceId;
  final EscrowStatus? status;
  final String? txHash;
  final String? createTxHash;
  final String? claimTxHash;
  final String? refundTxHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  const TradeEscrowModel({
    required this.id,
    this.claimableBalanceId,
    this.status,
    this.txHash,
    this.createTxHash,
    this.claimTxHash,
    this.refundTxHash,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  factory TradeEscrowModel.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return TradeEscrowModel(
      id: json['id']?.toString() ?? '',
      claimableBalanceId:
          json['claimableBalanceId']?.toString() ??
          json['claimable_balance_id']?.toString(),
      status: EscrowStatus.fromString(json['status']?.toString()),
      txHash: json['txHash']?.toString() ?? json['tx_hash']?.toString(),
      createTxHash:
          json['createTxHash']?.toString() ??
          json['create_tx_hash']?.toString(),
      claimTxHash:
          json['claimTxHash']?.toString() ?? json['claim_tx_hash']?.toString(),
      refundTxHash:
          json['refundTxHash']?.toString() ??
          json['refund_tx_hash']?.toString(),
      createdAt: readDate(json['createdAt'] ?? json['created_at']),
      updatedAt: readDate(json['updatedAt'] ?? json['updated_at']),
      expiresAt: readDate(json['expiresAt'] ?? json['expires_at']),
    );
  }

  TradeEscrowModel copyWith({
    String? claimableBalanceId,
    EscrowStatus? status,
    String? txHash,
    String? createTxHash,
    String? claimTxHash,
    String? refundTxHash,
    DateTime? expiresAt,
  }) {
    return TradeEscrowModel(
      id: id,
      claimableBalanceId: claimableBalanceId ?? this.claimableBalanceId,
      status: status ?? this.status,
      txHash: txHash ?? this.txHash,
      createTxHash: createTxHash ?? this.createTxHash,
      claimTxHash: claimTxHash ?? this.claimTxHash,
      refundTxHash: refundTxHash ?? this.refundTxHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// Type of offer - determines trade flow
enum TradeOfferType {
  buy,
  sell,
  unknown;

  static TradeOfferType fromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'BUY':
        return TradeOfferType.buy;
      case 'SELL':
        return TradeOfferType.sell;
      default:
        return TradeOfferType.unknown;
    }
  }

  /// Whether the current user is the buyer in this trade
  bool isUserBuyer(String currentUserId, String buyerId, String sellerId) {
    return currentUserId == buyerId;
  }
}

class TradeModel {
  final String id;
  final String offerId;
  final TradeStatus status;
  final TradeOfferType offerType;
  final String asset;
  final String fiatCurrency;
  final double cryptoAmount;
  final double fiatAmount;
  final double? priceSnapshot;
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
  final DateTime? paymentDueAt;
  final DateTime? fiatSentAt;
  final DateTime? fiatConfirmDueAt;
  final String? disputeId;
  final String? autoDisputeTrigger;
  final TradeEscrowModel? escrow;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? sellerPaymentAccount;
  final Map<String, dynamic>? buyerPaymentAccount;

  const TradeModel({
    required this.id,
    required this.offerId,
    required this.status,
    required this.offerType,
    required this.asset,
    required this.fiatCurrency,
    required this.cryptoAmount,
    required this.fiatAmount,
    this.priceSnapshot,
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
    this.paymentDueAt,
    this.fiatSentAt,
    this.fiatConfirmDueAt,
    this.disputeId,
    this.autoDisputeTrigger,
    this.escrow,
    this.offer,
    this.sellerPaymentAccount,
    this.buyerPaymentAccount,
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

    double? readDoubleOrNull(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is num) return v.toDouble();
        if (v is String) {
          final p = double.tryParse(v.trim());
          if (p != null) return p;
        }
      }
      return null;
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
    final disputeRaw = json['dispute'];
    final spaRaw =
        json['sellerPaymentAccount'] ?? json['seller_payment_account'];
    final bpaRaw =
        json['buyerPaymentAccount'] ??
        json['buyerPaymentAcc'] ??
        json['buyer_payment_account'] ??
        json['buyer_payment_acc'];

    // Read offer type from the nested offer object or directly from trade
    TradeOfferType readOfferType() {
      final type = json['offerType']?.toString() ?? json['type']?.toString();
      if (type != null && type.isNotEmpty) {
        return TradeOfferType.fromString(type);
      }
      // Try to get from offer object
      if (offerRaw is Map<String, dynamic>) {
        final offerType = offerRaw['type']?.toString();
        return TradeOfferType.fromString(offerType);
      }
      return TradeOfferType.unknown;
    }

    return TradeModel(
      id: readStr(const ['id']),
      offerId: readStr(const ['offerId', 'offer_id']),
      status: TradeStatus.fromString(json['status']?.toString()),
      offerType: readOfferType(),
      asset: readStr(const ['asset']),
      fiatCurrency: readStr(const ['fiatCurrency', 'fiat_currency']),
      cryptoAmount: readDouble(const ['cryptoAmount', 'crypto_amount']),
      fiatAmount: readDouble(const ['fiatAmount', 'fiat_amount']),
      priceSnapshot: readDoubleOrNull(const [
        'priceSnapshot',
        'price_snapshot',
      ]),
      buyerId: readStr(const ['buyerId', 'buyer_id']),
      sellerId: readStr(const ['sellerId', 'seller_id']),
      cryptoReceiverAddress: readStr(const [
        'cryptoReceiverAddress',
        'crypto_receiver_address',
      ]),
      cryptoReceiverMemo: (() {
        final v = readStr(const ['cryptoReceiverMemo', 'crypto_receiver_memo']);
        return v.isEmpty ? null : v;
      })(),
      sellerPaymentAccountId: readStr(const [
        'sellerPaymentAccountId',
        'seller_payment_account_id',
      ]),
      buyerPaymentAccountId: (() {
        final v = readStr(const [
          'buyerPaymentAccountId',
          'buyer_payment_account_id',
          'buyerPaymentAcc',
          'buyer_payment_acc',
        ]);
        return v.isEmpty ? null : v;
      })(),
      paymentWindowMinutes: readInt(const [
        'paymentWindowMinutes',
        'payment_window_minutes',
      ]),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
      expiresAt: readDate(const [
        'expiresAt',
        'expires_at',
        'paymentDeadline',
        'payment_deadline',
      ]),
      paymentDueAt: readDate(const ['paymentDueAt', 'payment_due_at']),
      fiatSentAt: readDate(const ['fiatSentAt', 'fiat_sent_at']),
      fiatConfirmDueAt: readDate(const [
        'fiatConfirmDueAt',
        'fiat_confirm_due_at',
      ]),
      disputeId: (() {
        final direct = readStr(const ['disputeId', 'dispute_id']);
        if (direct.isNotEmpty) return direct;
        if (disputeRaw is Map<String, dynamic>) {
          final nested =
              disputeRaw['id']?.toString().trim() ??
              disputeRaw['disputeId']?.toString().trim() ??
              disputeRaw['dispute_id']?.toString().trim() ??
              '';
          if (nested.isNotEmpty) return nested;
        }
        return null;
      })(),
      autoDisputeTrigger: (() {
        final v = readStr(const ['autoDisputeTrigger', 'auto_dispute_trigger']);
        return v.isEmpty ? null : v;
      })(),
      escrow: escrowRaw is Map<String, dynamic>
          ? TradeEscrowModel.fromJson(escrowRaw)
          : null,
      offer: offerRaw is Map<String, dynamic> ? offerRaw : null,
      sellerPaymentAccount: spaRaw is Map<String, dynamic> ? spaRaw : null,
      buyerPaymentAccount: bpaRaw is Map<String, dynamic> ? bpaRaw : null,
    );
  }

  TradeModel copyWith({
    TradeStatus? status,
    TradeEscrowModel? escrow,
    TradeOfferType? offerType,
    double? priceSnapshot,
    DateTime? paymentDueAt,
    DateTime? fiatSentAt,
    DateTime? fiatConfirmDueAt,
    String? disputeId,
    String? autoDisputeTrigger,
  }) {
    return TradeModel(
      id: id,
      offerId: offerId,
      status: status ?? this.status,
      offerType: offerType ?? this.offerType,
      asset: asset,
      fiatCurrency: fiatCurrency,
      cryptoAmount: cryptoAmount,
      fiatAmount: fiatAmount,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
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
      paymentDueAt: paymentDueAt ?? this.paymentDueAt,
      fiatSentAt: fiatSentAt ?? this.fiatSentAt,
      fiatConfirmDueAt: fiatConfirmDueAt ?? this.fiatConfirmDueAt,
      disputeId: disputeId ?? this.disputeId,
      autoDisputeTrigger: autoDisputeTrigger ?? this.autoDisputeTrigger,
      escrow: escrow ?? this.escrow,
      offer: offer,
      sellerPaymentAccount: sellerPaymentAccount,
      buyerPaymentAccount: buyerPaymentAccount,
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
