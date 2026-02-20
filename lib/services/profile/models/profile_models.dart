enum ProfileTier { normal, verified, merchant, vip, unknown }

ProfileTier profileTierFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'NORMAL':
      return ProfileTier.normal;
    case 'VERIFIED':
      return ProfileTier.verified;
    case 'MERCHANT':
      return ProfileTier.merchant;
    case 'VIP':
      return ProfileTier.vip;
    default:
      return ProfileTier.unknown;
  }
}

String profileTierToApi(ProfileTier tier) {
  switch (tier) {
    case ProfileTier.normal:
      return 'NORMAL';
    case ProfileTier.verified:
      return 'VERIFIED';
    case ProfileTier.merchant:
      return 'MERCHANT';
    case ProfileTier.vip:
      return 'VIP';
    case ProfileTier.unknown:
      return 'NORMAL';
  }
}

enum ProfileAvailability { available, unavailable, onBreak, unknown }

ProfileAvailability profileAvailabilityFromApi(dynamic raw) {
  final value = raw?.toString().trim().toUpperCase();
  switch (value) {
    case 'AVAILABLE':
      return ProfileAvailability.available;
    case 'UNAVAILABLE':
      return ProfileAvailability.unavailable;
    case 'ON_BREAK':
      return ProfileAvailability.onBreak;
    default:
      return ProfileAvailability.unknown;
  }
}

String profileAvailabilityToApi(ProfileAvailability availability) {
  switch (availability) {
    case ProfileAvailability.available:
      return 'AVAILABLE';
    case ProfileAvailability.unavailable:
      return 'UNAVAILABLE';
    case ProfileAvailability.onBreak:
      return 'ON_BREAK';
    case ProfileAvailability.unknown:
      return 'UNAVAILABLE';
  }
}

class ProfileModel {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? country;

  final bool isMerchant;
  final bool merchantRequestPending;
  final DateTime? merchantRequestedAt;
  final String? merchantRequestNote;

  final ProfileTier tier;
  final double completionRate;
  final double disputeRate;
  final double cancelRate;
  final double? avgReleaseTime;
  final int totalTrades;
  final double tradeVolume;

  final bool isVerified;
  final bool isActive;
  final ProfileAvailability availability;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final bool autoUnavailable;

  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? address;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.country,
    this.isMerchant = false,
    this.merchantRequestPending = false,
    this.merchantRequestedAt,
    this.merchantRequestNote,
    this.tier = ProfileTier.unknown,
    this.completionRate = 0,
    this.disputeRate = 0,
    this.cancelRate = 0,
    this.avgReleaseTime,
    this.totalTrades = 0,
    this.tradeVolume = 0,
    this.isVerified = false,
    this.isActive = true,
    this.availability = ProfileAvailability.unknown,
    this.availableFrom,
    this.availableTo,
    this.autoUnavailable = false,
    this.firstName,
    this.middleName,
    this.lastName,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
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

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        final parsed = parseDate(value);
        if (parsed != null) return parsed;
      }
      return null;
    }

    return ProfileModel(
      id: readString(const ['id']) ?? '',
      userId: readString(const ['userId', 'user_id']) ?? '',
      username: readString(const ['username']),
      displayName: readString(const ['displayName', 'display_name']),
      country: readString(const ['country']),
      isMerchant: readBool(const ['isMerchant', 'is_merchant']),
      merchantRequestPending: readBool(const [
        'merchantRequestPending',
        'merchant_request_pending',
      ]),
      merchantRequestedAt: readDate(const [
        'merchantRequestedAt',
        'merchant_requested_at',
      ]),
      merchantRequestNote: readString(const [
        'merchantRequestNote',
        'merchant_request_note',
      ]),
      tier: profileTierFromApi(json['tier']),
      completionRate: readDouble(const ['completionRate', 'completion_rate']),
      disputeRate: readDouble(const ['disputeRate', 'dispute_rate']),
      cancelRate: readDouble(const ['cancelRate', 'cancel_rate']),
      avgReleaseTime: (() {
        final value = json['avgReleaseTime'] ?? json['avg_release_time'];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value.trim());
        return null;
      })(),
      totalTrades: readInt(const ['totalTrades', 'total_trades']),
      tradeVolume: readDouble(const ['tradeVolume', 'trade_volume']),
      isVerified: readBool(const ['isVerified', 'is_verified']),
      isActive: readBool(const ['isActive', 'is_active'], fallback: true),
      availability: profileAvailabilityFromApi(json['availability']),
      availableFrom: readDate(const ['availableFrom', 'available_from']),
      availableTo: readDate(const ['availableTo', 'available_to']),
      autoUnavailable: readBool(const ['autoUnavailable', 'auto_unavailable']),
      firstName: readString(const ['firstName', 'first_name']),
      middleName: readString(const ['middleName', 'middle_name']),
      lastName: readString(const ['lastName', 'last_name']),
      address: readString(const ['address']),
      createdAt: readDate(const ['createdAt', 'created_at']),
      updatedAt: readDate(const ['updatedAt', 'updated_at']),
    );
  }

  bool get isVerificationIdentityComplete {
    bool hasValue(String? value) => value != null && value.trim().isNotEmpty;

    return hasValue(firstName) &&
        hasValue(lastName) &&
        hasValue(country) &&
        hasValue(address);
  }
}

class MerchantRequestStatusModel {
  final String userId;
  final bool isMerchant;
  final bool merchantRequestPending;
  final DateTime? merchantRequestedAt;
  final String? merchantRequestNote;

  const MerchantRequestStatusModel({
    required this.userId,
    required this.isMerchant,
    required this.merchantRequestPending,
    this.merchantRequestedAt,
    this.merchantRequestNote,
  });

  factory MerchantRequestStatusModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    bool readBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    return MerchantRequestStatusModel(
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      isMerchant: readBool(json['isMerchant'] ?? json['is_merchant']),
      merchantRequestPending: readBool(
        json['merchantRequestPending'] ?? json['merchant_request_pending'],
      ),
      merchantRequestedAt: parseDate(
        json['merchantRequestedAt'] ?? json['merchant_requested_at'],
      ),
      merchantRequestNote:
          (json['merchantRequestNote'] ?? json['merchant_request_note'])
              ?.toString(),
    );
  }
}
