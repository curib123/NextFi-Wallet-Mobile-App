import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

enum TradeStatus {
  created,
  awaitingPayment,
  paid,
  released,
  cancelled,
  disputed,
  expired,
  refunded,
  unknown,
}

TradeStatus tradeStatusFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'CREATED':
    case 'PENDING':
      return TradeStatus.created;
    case 'OPEN':
    case 'AWAITING_PAYMENT':
    case 'PENDING_PAYMENT':
    case 'FUNDED':
      return TradeStatus.awaitingPayment;
    case 'PAID':
      return TradeStatus.paid;
    case 'RELEASED':
    case 'COMPLETED':
      return TradeStatus.released;
    case 'CANCELLED':
      return TradeStatus.cancelled;
    case 'DISPUTED':
    case 'UNDER_REVIEW':
      return TradeStatus.disputed;
    case 'EXPIRED':
      return TradeStatus.expired;
    case 'REFUNDED':
      return TradeStatus.refunded;
    default:
      return TradeStatus.unknown;
  }
}

String tradeStatusToApi(TradeStatus status) {
  switch (status) {
    case TradeStatus.created:
      return 'CREATED';
    case TradeStatus.awaitingPayment:
      return 'AWAITING_PAYMENT';
    case TradeStatus.paid:
      return 'PAID';
    case TradeStatus.released:
      return 'RELEASED';
    case TradeStatus.cancelled:
      return 'CANCELLED';
    case TradeStatus.disputed:
      return 'DISPUTED';
    case TradeStatus.expired:
      return 'EXPIRED';
    case TradeStatus.refunded:
      return 'REFUNDED';
    case TradeStatus.unknown:
      return 'UNKNOWN';
  }
}

enum TradeEscrowState { unfunded, funded, released, refunded, unknown }

TradeEscrowState tradeEscrowStateFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'UNFUNDED':
      return TradeEscrowState.unfunded;
    case 'FUNDED':
      return TradeEscrowState.funded;
    case 'RELEASED':
      return TradeEscrowState.released;
    case 'REFUNDED':
      return TradeEscrowState.refunded;
    default:
      return TradeEscrowState.unknown;
  }
}

class TradeWalletRef {
  final String id;
  final String publicAddress;
  final String network;
  final String? label;

  const TradeWalletRef({
    required this.id,
    required this.publicAddress,
    required this.network,
    this.label,
  });

  factory TradeWalletRef.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final label = readString(const ['label']);
    return TradeWalletRef(
      id: readString(const ['id', 'walletId', 'wallet_id']),
      publicAddress: readString(const [
        'publicAddress',
        'public_address',
        'address',
      ]),
      network: readString(const ['network'], fallback: 'stellar'),
      label: label.isEmpty ? null : label,
    );
  }
}

class TradeMessageModel {
  final String id;
  final String tradeId;
  final String senderId;
  final String message;
  final DateTime? createdAt;

  const TradeMessageModel({
    required this.id,
    required this.tradeId,
    required this.senderId,
    required this.message,
    this.createdAt,
  });

  factory TradeMessageModel.fromJson(Map<String, dynamic> json) {
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

    return TradeMessageModel(
      id: readString(const ['id']),
      tradeId: readString(const ['tradeId', 'trade_id']),
      senderId: readString(const ['senderId', 'sender_id']),
      message: readString(const ['message']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

class TradeProofModel {
  final String id;
  final String? imageUrl;
  final String? note;
  final String? uploadedById;
  final DateTime? createdAt;

  const TradeProofModel({
    required this.id,
    this.imageUrl,
    this.note,
    this.uploadedById,
    this.createdAt,
  });

  factory TradeProofModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    String? readNullableString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return TradeProofModel(
      id: readNullableString(const ['id']) ?? '',
      imageUrl: readNullableString(const ['imageUrl', 'image_url', 'url']),
      note: readNullableString(const ['note']),
      uploadedById: readNullableString(const [
        'uploadedById',
        'uploaded_by_id',
      ]),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

class TradeModel {
  final String id;
  final String offerId;
  final String buyerId;
  final String sellerId;
  final TradeStatus status;
  final String statusRaw;
  final OfferAsset asset;
  final String fiatCurrency;
  final double amount;
  final double? price;
  final double? fiatAmount;
  final int paymentWindow;
  final DateTime? expiresAt;
  final String? note;
  final String? cancelReason;
  final TradeEscrowState escrowState;
  final String? claimableBalanceId;
  final String? fundedTxHash;
  final String? releasedTxHash;
  final String? refundTxHash;
  final DateTime? escrowFundedAt;
  final DateTime? escrowReleasedAt;
  final DateTime? escrowRefundedAt;
  final DateTime? escrowExpiryAt;
  final DateTime? paymentDueAt;
  final DateTime? releaseDueAt;
  final String? buyerWalletId;
  final String? sellerWalletId;
  final TradeWalletRef? buyerWallet;
  final TradeWalletRef? sellerWallet;
  final String? escrowTxHash;
  final String? releaseTxHash;
  final UserPaymentAccountModel? buyerPaymentAccount;
  final UserPaymentAccountModel? sellerPaymentAccount;
  final List<TradeMessageModel> messages;
  final List<TradeProofModel> proofs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TradeModel({
    required this.id,
    required this.offerId,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.statusRaw,
    required this.asset,
    required this.fiatCurrency,
    required this.amount,
    this.price,
    this.fiatAmount,
    required this.paymentWindow,
    this.expiresAt,
    this.note,
    this.cancelReason,
    this.escrowState = TradeEscrowState.unknown,
    this.claimableBalanceId,
    this.fundedTxHash,
    this.releasedTxHash,
    this.refundTxHash,
    this.escrowFundedAt,
    this.escrowReleasedAt,
    this.escrowRefundedAt,
    this.escrowExpiryAt,
    this.paymentDueAt,
    this.releaseDueAt,
    this.buyerWalletId,
    this.sellerWalletId,
    this.buyerWallet,
    this.sellerWallet,
    this.escrowTxHash,
    this.releaseTxHash,
    this.buyerPaymentAccount,
    this.sellerPaymentAccount,
    this.messages = const [],
    this.proofs = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory TradeModel.fromJson(Map<String, dynamic> json) {
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

    String? readNullableString(List<String> keys) {
      final value = readString(keys);
      return value.isEmpty ? null : value;
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

    List<TradeMessageModel> readMessages() {
      final candidates = [
        json['messages'],
        json['chatMessages'],
        json['chat_messages'],
      ];
      for (final raw in candidates) {
        if (raw is! List) continue;
        final items = raw
            .whereType<Map<String, dynamic>>()
            .map(TradeMessageModel.fromJson)
            .toList();
        items.sort(
          (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        );
        return items;
      }
      return const [];
    }

    List<TradeProofModel> readProofs() {
      final candidates = [
        json['proofs'],
        json['paymentProofs'],
        json['payment_proofs'],
      ];
      for (final raw in candidates) {
        if (raw is! List) continue;
        return raw
            .whereType<Map<String, dynamic>>()
            .map(TradeProofModel.fromJson)
            .toList();
      }
      return const [];
    }

    UserPaymentAccountModel? readPaymentAccount(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is Map<String, dynamic>) {
          return UserPaymentAccountModel.fromJson(raw);
        }
      }
      return null;
    }

    TradeWalletRef? readWallet(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is! Map<String, dynamic>) continue;
        final wallet = TradeWalletRef.fromJson(raw);
        if (wallet.id.isNotEmpty || wallet.publicAddress.isNotEmpty) {
          return wallet;
        }
      }
      return null;
    }

    final statusRaw = readString(const ['status'], fallback: 'UNKNOWN');
    final fundedTxHash = readNullableString(const [
      'fundedTxHash',
      'funded_tx_hash',
      'escrowTxHash',
      'escrow_tx_hash',
    ]);
    final releasedTxHash = readNullableString(const [
      'releasedTxHash',
      'released_tx_hash',
      'releaseTxHash',
      'release_tx_hash',
    ]);
    final buyerWallet = readWallet(const ['buyerWallet', 'buyer_wallet']);
    final sellerWallet = readWallet(const ['sellerWallet', 'seller_wallet']);

    return TradeModel(
      id: readString(const ['id']),
      offerId: readString(const ['offerId', 'offer_id']),
      buyerId: readString(const ['buyerId', 'buyer_id']),
      sellerId: readString(const ['sellerId', 'seller_id']),
      status: tradeStatusFromApi(statusRaw),
      statusRaw: statusRaw,
      asset: offerAssetFromApi(json['asset']),
      fiatCurrency: readString(const [
        'fiatCurrency',
        'fiat_currency',
      ], fallback: 'PHP'),
      amount: readDouble(const ['amount']),
      price: readNullableDouble(const ['price']),
      fiatAmount: readNullableDouble(const ['fiatAmount', 'fiat_amount']),
      paymentWindow: readInt(const [
        'paymentWindow',
        'payment_window',
      ], fallback: 15),
      expiresAt: parseDate(json['expiresAt'] ?? json['expires_at']),
      note: readNullableString(const ['note']),
      cancelReason: readNullableString(const ['cancelReason', 'cancel_reason']),
      escrowState: tradeEscrowStateFromApi(
        json['escrowState'] ?? json['escrow_state'],
      ),
      claimableBalanceId: readNullableString(const [
        'claimableBalanceId',
        'claimable_balance_id',
      ]),
      fundedTxHash: fundedTxHash,
      releasedTxHash: releasedTxHash,
      refundTxHash: readNullableString(const [
        'refundTxHash',
        'refund_tx_hash',
      ]),
      escrowFundedAt: parseDate(
        json['escrowFundedAt'] ?? json['escrow_funded_at'],
      ),
      escrowReleasedAt: parseDate(
        json['escrowReleasedAt'] ?? json['escrow_released_at'],
      ),
      escrowRefundedAt: parseDate(
        json['escrowRefundedAt'] ?? json['escrow_refunded_at'],
      ),
      escrowExpiryAt: parseDate(
        json['escrowExpiryAt'] ?? json['escrow_expiry_at'],
      ),
      paymentDueAt: parseDate(json['paymentDueAt'] ?? json['payment_due_at']),
      releaseDueAt: parseDate(json['releaseDueAt'] ?? json['release_due_at']),
      buyerWalletId: readNullableString(const [
        'buyerWalletId',
        'buyer_wallet_id',
      ]),
      sellerWalletId: readNullableString(const [
        'sellerWalletId',
        'seller_wallet_id',
      ]),
      buyerWallet: buyerWallet,
      sellerWallet: sellerWallet,
      escrowTxHash: fundedTxHash,
      releaseTxHash: releasedTxHash,
      buyerPaymentAccount: readPaymentAccount(const [
        'buyerPaymentAccount',
        'buyer_payment_account',
      ]),
      sellerPaymentAccount: readPaymentAccount(const [
        'sellerPaymentAccount',
        'seller_payment_account',
      ]),
      messages: readMessages(),
      proofs: readProofs(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  DateTime? get paymentDeadline {
    if (paymentDueAt != null) return paymentDueAt;
    if (expiresAt != null) return expiresAt;
    if (createdAt == null) return null;
    return createdAt!.add(Duration(minutes: paymentWindow));
  }

  bool get isOpenForBuyerPayment =>
      status == TradeStatus.awaitingPayment || status == TradeStatus.created;

  bool get isFinalStatus =>
      status == TradeStatus.released ||
      status == TradeStatus.cancelled ||
      status == TradeStatus.expired ||
      status == TradeStatus.refunded;
}
