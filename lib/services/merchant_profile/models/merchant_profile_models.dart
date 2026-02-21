// ── Enums ─────────────────────────────────────────────────────────────────────

enum MerchantType { individual, business, unknown }

MerchantType merchantTypeFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'INDIVIDUAL':
      return MerchantType.individual;
    case 'BUSINESS':
      return MerchantType.business;
    default:
      return MerchantType.unknown;
  }
}

String merchantTypeToApi(MerchantType type) {
  switch (type) {
    case MerchantType.individual:
      return 'INDIVIDUAL';
    case MerchantType.business:
      return 'BUSINESS';
    case MerchantType.unknown:
      return 'INDIVIDUAL';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum MerchantStatus { pending, approved, rejected, suspended, unknown }

MerchantStatus merchantStatusFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'PENDING':
      return MerchantStatus.pending;
    case 'APPROVED':
      return MerchantStatus.approved;
    case 'REJECTED':
      return MerchantStatus.rejected;
    case 'SUSPENDED':
      return MerchantStatus.suspended;
    default:
      return MerchantStatus.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum MerchantTier { basic, standard, premium, vip, unknown }

MerchantTier merchantTierFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'BASIC':
      return MerchantTier.basic;
    case 'STANDARD':
      return MerchantTier.standard;
    case 'PREMIUM':
      return MerchantTier.premium;
    case 'VIP':
      return MerchantTier.vip;
    default:
      return MerchantTier.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum SellerAvailability { available, unavailable, onBreak, unknown }

SellerAvailability sellerAvailabilityFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'AVAILABLE':
      return SellerAvailability.available;
    case 'UNAVAILABLE':
      return SellerAvailability.unavailable;
    case 'ON_BREAK':
      return SellerAvailability.onBreak;
    default:
      return SellerAvailability.unknown;
  }
}

String sellerAvailabilityToApi(SellerAvailability availability) {
  switch (availability) {
    case SellerAvailability.available:
      return 'AVAILABLE';
    case SellerAvailability.unavailable:
      return 'UNAVAILABLE';
    case SellerAvailability.onBreak:
      return 'ON_BREAK';
    case SellerAvailability.unknown:
      return 'UNAVAILABLE';
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class MerchantProfileModel {
  final String id;
  final String userId;
  final MerchantType type;
  final MerchantStatus status;
  final MerchantTier tier;
  final String displayName;
  final String? bio;
  final String? country;
  final String? location;
  final String? email;
  final String? phone;

  // Business info
  final String? businessName;
  final String? registrationNumber;
  final String? businessAddress;
  final String? authorizedRepName;
  final String? authorizedRepPosition;
  final String? businessDocumentUrl;
  final String? authorizationLetterUrl;

  // Default crypto receiving info
  final String? defaultCryptoAddress;
  final String? defaultCryptoMemo;

  // Availability
  final SellerAvailability availability;
  final bool autoUnavailable;
  final DateTime? availableFrom;
  final DateTime? availableTo;

  // Admin review fields
  final String? requestNote;
  final String? decisionNote;
  final String? rejectionReason;
  final String? suspendReason;

  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? suspendedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MerchantProfileModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.tier,
    required this.displayName,
    this.bio,
    this.country,
    this.location,
    this.email,
    this.phone,
    this.businessName,
    this.registrationNumber,
    this.businessAddress,
    this.authorizedRepName,
    this.authorizedRepPosition,
    this.businessDocumentUrl,
    this.authorizationLetterUrl,
    this.defaultCryptoAddress,
    this.defaultCryptoMemo,
    this.availability = SellerAvailability.unknown,
    this.autoUnavailable = false,
    this.availableFrom,
    this.availableTo,
    this.requestNote,
    this.decisionNote,
    this.rejectionReason,
    this.suspendReason,
    this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    this.suspendedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory MerchantProfileModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
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
        final parsed = parseDate(json[key]);
        if (parsed != null) return parsed;
      }
      return null;
    }

    return MerchantProfileModel(
      id: readString(const ['id']) ?? '',
      userId: readString(const ['userId', 'user_id']) ?? '',
      type: merchantTypeFromApi(json['type']),
      status: merchantStatusFromApi(json['status']),
      tier: merchantTierFromApi(json['tier']),
      displayName: readString(const ['displayName', 'display_name']) ?? '',
      bio: readString(const ['bio']),
      country: readString(const ['country']),
      location: readString(const ['location']),
      email: readString(const ['email']),
      phone: readString(const ['phone']),
      businessName: readString(const ['businessName', 'business_name']),
      registrationNumber: readString(const [
        'registrationNumber',
        'registration_number',
      ]),
      businessAddress: readString(const ['businessAddress', 'business_address']),
      authorizedRepName: readString(const [
        'authorizedRepName',
        'authorized_rep_name',
      ]),
      authorizedRepPosition: readString(const [
        'authorizedRepPosition',
        'authorized_rep_position',
      ]),
      businessDocumentUrl: readString(const [
        'businessDocumentUrl',
        'business_document_url',
      ]),
      authorizationLetterUrl: readString(const [
        'authorizationLetterUrl',
        'authorization_letter_url',
      ]),
      defaultCryptoAddress: readString(const [
        'defaultCryptoAddress',
        'default_crypto_address',
      ]),
      defaultCryptoMemo: readString(const [
        'defaultCryptoMemo',
        'default_crypto_memo',
      ]),
      availability: sellerAvailabilityFromApi(json['availability']),
      autoUnavailable: readBool(const ['autoUnavailable', 'auto_unavailable']),
      availableFrom: readDate(const ['availableFrom', 'available_from']),
      availableTo: readDate(const ['availableTo', 'available_to']),
      requestNote: readString(const ['requestNote', 'request_note']),
      decisionNote: readString(const ['decisionNote', 'decision_note']),
      rejectionReason: readString(const ['rejectionReason', 'rejection_reason']),
      suspendReason: readString(const ['suspendReason', 'suspend_reason']),
      requestedAt: readDate(const ['requestedAt', 'requested_at']),
      approvedAt: readDate(const ['approvedAt', 'approved_at']),
      rejectedAt: readDate(const ['rejectedAt', 'rejected_at']),
      suspendedAt: readDate(const ['suspendedAt', 'suspended_at']),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
    );
  }

  bool get isApproved => status == MerchantStatus.approved;
  bool get isPending => status == MerchantStatus.pending;
  bool get isRejected => status == MerchantStatus.rejected;
  bool get isSuspended => status == MerchantStatus.suspended;
}
