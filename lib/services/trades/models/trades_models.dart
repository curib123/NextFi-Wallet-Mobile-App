import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

// ─── TradeStatus ─────────────────────────────────────────────────────────────

enum TradeStatus {
  // New vF1 SELL flow
  awaitingFiat,
  fiatSent,
  fiatConfirmed,
  deliveryCbCreated,
  claimed,
  // New vF1 BUY flow
  awaitingCrypto,
  cryptoConfirmed,
  awaitingUserConfirm,
  overdue,
  // Shared terminal
  completed,
  // Legacy statuses (kept for backward compat)
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
    // New vF1 SELL
    case 'AWAITING_FIAT':
      return TradeStatus.awaitingFiat;
    case 'FIAT_SENT':
      return TradeStatus.fiatSent;
    case 'FIAT_CONFIRMED':
      return TradeStatus.fiatConfirmed;
    case 'DELIVERY_CB_CREATED':
      return TradeStatus.deliveryCbCreated;
    case 'CLAIMED':
      return TradeStatus.claimed;
    // New vF1 BUY
    case 'AWAITING_CRYPTO':
      return TradeStatus.awaitingCrypto;
    case 'CRYPTO_CONFIRMED':
      return TradeStatus.cryptoConfirmed;
    case 'AWAITING_USER_CONFIRM':
      return TradeStatus.awaitingUserConfirm;
    case 'OVERDUE':
      return TradeStatus.overdue;
    // Shared terminal
    case 'COMPLETED':
      return TradeStatus.completed;
    // Legacy
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
    case TradeStatus.awaitingFiat:
      return 'AWAITING_FIAT';
    case TradeStatus.fiatSent:
      return 'FIAT_SENT';
    case TradeStatus.fiatConfirmed:
      return 'FIAT_CONFIRMED';
    case TradeStatus.deliveryCbCreated:
      return 'DELIVERY_CB_CREATED';
    case TradeStatus.claimed:
      return 'CLAIMED';
    case TradeStatus.awaitingCrypto:
      return 'AWAITING_CRYPTO';
    case TradeStatus.cryptoConfirmed:
      return 'CRYPTO_CONFIRMED';
    case TradeStatus.awaitingUserConfirm:
      return 'AWAITING_USER_CONFIRM';
    case TradeStatus.overdue:
      return 'OVERDUE';
    case TradeStatus.completed:
      return 'COMPLETED';
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

// ─── TradeEscrowState ─────────────────────────────────────────────────────────

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

// ─── TradeMessageType ─────────────────────────────────────────────────────────

enum TradeMessageType { text, system }

TradeMessageType tradeMessageTypeFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  if (value == 'SYSTEM') return TradeMessageType.system;
  return TradeMessageType.text;
}

// ─── TradeWalletRef ───────────────────────────────────────────────────────────

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

// ─── TradeMessageModel ────────────────────────────────────────────────────────

class TradeMessageModel {
  final String id;
  final String tradeId;
  final String? senderId; // null for SYSTEM messages
  final String message;
  final TradeMessageType type;
  final DateTime? createdAt;

  const TradeMessageModel({
    required this.id,
    required this.tradeId,
    this.senderId,
    required this.message,
    this.type = TradeMessageType.text,
    this.createdAt,
  });

  bool get isSystem => type == TradeMessageType.system || senderId == null;

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

    String? readNullableString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final typeRaw = json['type'];
    return TradeMessageModel(
      id: readString(const ['id']),
      tradeId: readString(const ['tradeId', 'trade_id']),
      senderId: readNullableString(const ['senderId', 'sender_id']),
      message: readString(const ['message']),
      type: tradeMessageTypeFromApi(typeRaw),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
    );
  }
}

// ─── TradePartyLite ───────────────────────────────────────────────────────────

class TradePartyLite {
  final String id;
  final String email;
  final String name;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  const TradePartyLite({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  TradePartyLite copyWith({
    String? id,
    String? email,
    String? name,
    String? username,
    String? displayName,
    String? avatarUrl,
  }) {
    return TradePartyLite(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory TradePartyLite.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {Map<String, dynamic>? from}) {
      final src = from ?? json;
      for (final key in keys) {
        final value = src[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    Map<String, dynamic>? readMap(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is Map<String, dynamic>) return value;
        if (value is Map) {
          return value.map((k, v) => MapEntry(k.toString(), v));
        }
      }
      return null;
    }

    final profile = readMap(const ['profile', 'userProfile', 'user_profile']);
    final resolvedDisplayName = (() {
      final direct = readString(const ['displayName', 'display_name']);
      if (direct.isNotEmpty) return direct;
      if (profile != null) {
        final fromProfile = readString(const [
          'displayName',
          'display_name',
        ], from: profile);
        if (fromProfile.isNotEmpty) return fromProfile;
      }
      return null;
    })();

    final resolvedUsername = (() {
      final direct = readString(const ['username']);
      if (direct.isNotEmpty) return direct;
      if (profile != null) {
        final fromProfile = readString(const ['username'], from: profile);
        if (fromProfile.isNotEmpty) return fromProfile;
      }
      return null;
    })();

    final resolvedName = (() {
      final direct = readString(const ['name', 'fullName', 'full_name']);
      if (direct.isNotEmpty) return direct;
      if (resolvedDisplayName != null &&
          resolvedDisplayName.trim().isNotEmpty) {
        return resolvedDisplayName.trim();
      }
      if (profile != null) {
        final fullName = readString(const [
          'name',
          'fullName',
          'full_name',
        ], from: profile);
        if (fullName.isNotEmpty) return fullName;

        final parts = [
          readString(const ['firstName', 'first_name'], from: profile),
          readString(const ['middleName', 'middle_name'], from: profile),
          readString(const ['lastName', 'last_name'], from: profile),
        ].where((part) => part.isNotEmpty).toList();
        if (parts.isNotEmpty) return parts.join(' ').trim();
      }
      return '';
    })();

    final avatar = readString(const ['avatarUrl', 'avatar_url', 'avatar']);

    return TradePartyLite(
      id: readString(const ['id', 'userId', 'user_id']),
      email: readString(const ['email']),
      name: resolvedName,
      username: resolvedUsername,
      displayName: resolvedDisplayName,
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }
}

// ─── TradeProofModel ──────────────────────────────────────────────────────────

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

// ─── TradeModel ───────────────────────────────────────────────────────────────

class TradeModel {
  final String id;
  final String offerId;
  final String buyerId;
  final String sellerId;
  final TradePartyLite? buyer;
  final TradePartyLite? seller;
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

  // Legacy escrow fields
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
  final String? escrowTxHash;
  final String? releaseTxHash;

  // Wallet refs
  final String? buyerWalletId;
  final String? sellerWalletId;
  final TradeWalletRef? buyerWallet;
  final TradeWalletRef? sellerWallet;

  // Payment accounts
  final UserPaymentAccountModel? buyerPaymentAccount;
  final UserPaymentAccountModel? sellerPaymentAccount;

  // Messages & proofs
  final List<TradeMessageModel> messages;
  final List<TradeProofModel> proofs;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── vF1 NEW SELL fields ───────────────────────────────────────────────────
  final String? deliveryCbId; // claimable balance ID for delivery
  final DateTime? fiatDeadlineAt; // user must click fiat-sent by this time
  final DateTime? merchantSlaDeadlineAt; // merchant must create CB delivery
  final DateTime? fiatSentAt; // when user clicked fiat-sent
  final DateTime? fiatConfirmedAt; // when merchant confirmed fiat
  final DateTime? claimedAt; // when user claimed CB

  // ── vF1 NEW BUY fields ────────────────────────────────────────────────────
  final String? depositAddress; // merchant wallet address for deposit
  final String? requiredMemo; // unique memo for watcher matching
  final DateTime? cryptoSendDeadlineAt; // user must send crypto by this time
  final DateTime? merchantFiatDeadlineAt; // merchant must send fiat by this time
  final DateTime? cryptoConfirmedAt; // when watcher confirmed deposit
  final DateTime? fiatSentByMerchantAt; // when merchant marked fiat sent
  final DateTime? overdueAt; // when trade went overdue
  final String? depositTxHash; // confirmed deposit transaction hash
  final String? depositOperationId; // confirmed deposit operation ID

  const TradeModel({
    required this.id,
    required this.offerId,
    required this.buyerId,
    required this.sellerId,
    this.buyer,
    this.seller,
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
    // vF1 SELL
    this.deliveryCbId,
    this.fiatDeadlineAt,
    this.merchantSlaDeadlineAt,
    this.fiatSentAt,
    this.fiatConfirmedAt,
    this.claimedAt,
    // vF1 BUY
    this.depositAddress,
    this.requiredMemo,
    this.cryptoSendDeadlineAt,
    this.merchantFiatDeadlineAt,
    this.cryptoConfirmedAt,
    this.fiatSentByMerchantAt,
    this.overdueAt,
    this.depositTxHash,
    this.depositOperationId,
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

    Map<String, dynamic>? asMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
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
    final buyerId = readString(const ['buyerId', 'buyer_id']);
    final sellerId = readString(const ['sellerId', 'seller_id']);
    final buyerRaw =
        asMap(json['buyer']) ??
        asMap(json['buyerUser']) ??
        asMap(json['buyer_user']) ??
        asMap(json['buyerAccount']) ??
        asMap(json['buyer_account']);
    final sellerRaw =
        asMap(json['seller']) ??
        asMap(json['sellerUser']) ??
        asMap(json['seller_user']) ??
        asMap(json['sellerAccount']) ??
        asMap(json['seller_account']);
    final buyerParty = (() {
      if (buyerRaw == null) return null;
      var party = TradePartyLite.fromJson(buyerRaw);
      if (party.id.isEmpty && buyerId.isNotEmpty) {
        party = party.copyWith(id: buyerId);
      }
      final hasInfo =
          party.id.isNotEmpty ||
          party.email.isNotEmpty ||
          party.name.isNotEmpty ||
          (party.username?.trim().isNotEmpty ?? false) ||
          (party.displayName?.trim().isNotEmpty ?? false);
      return hasInfo ? party : null;
    })();
    final sellerParty = (() {
      if (sellerRaw == null) return null;
      var party = TradePartyLite.fromJson(sellerRaw);
      if (party.id.isEmpty && sellerId.isNotEmpty) {
        party = party.copyWith(id: sellerId);
      }
      final hasInfo =
          party.id.isNotEmpty ||
          party.email.isNotEmpty ||
          party.name.isNotEmpty ||
          (party.username?.trim().isNotEmpty ?? false) ||
          (party.displayName?.trim().isNotEmpty ?? false);
      return hasInfo ? party : null;
    })();
    final buyerWallet = readWallet(const ['buyerWallet', 'buyer_wallet']);
    final sellerWallet = readWallet(const ['sellerWallet', 'seller_wallet']);

    // vF1: delivery sub-object
    Map<String, dynamic>? deliveryJson;
    final rawDelivery = json['delivery'] ?? json['tradeDelivery'];
    if (rawDelivery is Map<String, dynamic>) deliveryJson = rawDelivery;

    String? readDeliveryNullable(List<String> keys) {
      // Check top-level first, then delivery sub-object
      final top = readNullableString(keys);
      if (top != null) return top;
      if (deliveryJson == null) return null;
      for (final key in keys) {
        final value = deliveryJson![key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    DateTime? readDeliveryDate(List<String> keys) {
      final top = readNullableString(keys);
      if (top != null) return DateTime.tryParse(top);
      if (deliveryJson == null) return null;
      for (final key in keys) {
        final value = deliveryJson![key];
        if (value == null) continue;
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    return TradeModel(
      id: readString(const ['id']),
      offerId: readString(const ['offerId', 'offer_id']),
      buyerId: buyerId,
      sellerId: sellerId,
      buyer: buyerParty,
      seller: sellerParty,
      status: tradeStatusFromApi(statusRaw),
      statusRaw: statusRaw,
      asset: offerAssetFromApi(json['asset']),
      fiatCurrency: readString(const [
        'fiatCurrency',
        'fiat_currency',
      ], fallback: 'PHP'),
      amount: readDouble(const ['amount']),
      price: readNullableDouble(const ['price', 'priceSnapshot', 'price_snapshot']),
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
      // vF1 SELL
      deliveryCbId: readDeliveryNullable(const [
        'deliveryCbId',
        'delivery_cb_id',
        'claimableBalanceId',
        'claimable_balance_id',
      ]),
      fiatDeadlineAt: parseDate(
        json['fiatDeadlineAt'] ?? json['fiat_deadline_at'],
      ),
      merchantSlaDeadlineAt: parseDate(
        json['merchantSlaDeadlineAt'] ?? json['merchant_sla_deadline_at'],
      ),
      fiatSentAt: parseDate(json['fiatSentAt'] ?? json['fiat_sent_at']),
      fiatConfirmedAt: parseDate(
        json['fiatConfirmedAt'] ?? json['fiat_confirmed_at'],
      ),
      claimedAt: parseDate(json['claimedAt'] ?? json['claimed_at']),
      // vF1 BUY
      depositAddress: readNullableString(const [
        'depositAddress',
        'deposit_address',
      ]),
      requiredMemo: readNullableString(const [
        'requiredMemo',
        'required_memo',
      ]),
      cryptoSendDeadlineAt: parseDate(
        json['cryptoSendDeadlineAt'] ?? json['crypto_send_deadline_at'],
      ),
      merchantFiatDeadlineAt: parseDate(
        json['merchantFiatDeadlineAt'] ?? json['merchant_fiat_deadline_at'],
      ),
      cryptoConfirmedAt: parseDate(
        json['cryptoConfirmedAt'] ?? json['crypto_confirmed_at'],
      ),
      fiatSentByMerchantAt: parseDate(
        json['fiatSentByMerchantAt'] ?? json['fiat_sent_by_merchant_at'],
      ),
      overdueAt: parseDate(json['overdueAt'] ?? json['overdue_at']),
      depositTxHash: readNullableString(const [
        'depositTxHash',
        'deposit_tx_hash',
      ]),
      depositOperationId: readNullableString(const [
        'depositOperationId',
        'deposit_operation_id',
      ]),
    );
  }

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Returns the most relevant deadline for the current status.
  DateTime? get paymentDeadline {
    // vF1 BUY deadlines
    if (status == TradeStatus.awaitingCrypto && cryptoSendDeadlineAt != null) {
      return cryptoSendDeadlineAt;
    }
    if ((status == TradeStatus.cryptoConfirmed ||
            status == TradeStatus.awaitingUserConfirm ||
            status == TradeStatus.overdue) &&
        merchantFiatDeadlineAt != null) {
      return merchantFiatDeadlineAt;
    }
    // vF1 SELL deadlines
    if (status == TradeStatus.awaitingFiat && fiatDeadlineAt != null) {
      return fiatDeadlineAt;
    }
    if (status == TradeStatus.fiatConfirmed && merchantSlaDeadlineAt != null) {
      return merchantSlaDeadlineAt;
    }
    // Legacy / fallback
    if (paymentDueAt != null) return paymentDueAt;
    if (expiresAt != null) return expiresAt;
    if (createdAt == null) return null;
    return createdAt!.add(Duration(minutes: paymentWindow));
  }

  /// True when the buyer (user) can act on a SELL offer (pay fiat).
  bool get isOpenForBuyerPayment =>
      status == TradeStatus.awaitingFiat ||
      status == TradeStatus.awaitingPayment ||
      status == TradeStatus.created;

  /// True when the user (seller in BUY offer) must send crypto.
  bool get isAwaitingCrypto => status == TradeStatus.awaitingCrypto;

  bool get isFinalStatus =>
      status == TradeStatus.completed ||
      status == TradeStatus.claimed ||
      status == TradeStatus.released ||
      status == TradeStatus.cancelled ||
      status == TradeStatus.expired ||
      status == TradeStatus.refunded;

  bool get isDisputable =>
      !isFinalStatus || status == TradeStatus.disputed;

  TradePartyLite? partyForUserId(String? userId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) return null;
    if (buyer?.id == id || buyerId == id) {
      return buyer ?? TradePartyLite(id: buyerId, email: '', name: '');
    }
    if (seller?.id == id || sellerId == id) {
      return seller ?? TradePartyLite(id: sellerId, email: '', name: '');
    }
    return null;
  }

  TradePartyLite? counterpartyFor(String? currentUserId) {
    final me = currentUserId?.trim() ?? '';
    if (me.isEmpty) return null;
    if (buyerId == me) {
      return seller ?? TradePartyLite(id: sellerId, email: '', name: '');
    }
    if (sellerId == me) {
      return buyer ?? TradePartyLite(id: buyerId, email: '', name: '');
    }
    return null;
  }
}
