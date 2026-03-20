import 'merchant_profile_models.dart';

class RequestMerchantProfileRequest {
  final MerchantType type;
  final String displayName;
  final String? requestNote;
  final String? country;
  final String? location;
  final String? email;
  final String? phone;
  final String? businessName;
  final String? registrationNumber;
  final String? businessAddress;
  final String? authorizedRepName;
  final String? authorizedRepPosition;

  const RequestMerchantProfileRequest({
    required this.type,
    required this.displayName,
    this.requestNote,
    this.country,
    this.location,
    this.email,
    this.phone,
    this.businessName,
    this.registrationNumber,
    this.businessAddress,
    this.authorizedRepName,
    this.authorizedRepPosition,
  });

  static String? _trim(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    'type': merchantTypeToApi(type),
    'displayName': displayName.trim(),
    if (_trim(requestNote) != null) 'requestNote': _trim(requestNote),
    if (_trim(country) != null) 'country': _trim(country),
    if (_trim(location) != null) 'location': _trim(location),
    if (_trim(email) != null) 'email': _trim(email),
    if (_trim(phone) != null) 'phone': _trim(phone),
    if (_trim(businessName) != null) 'businessName': _trim(businessName),
    if (_trim(registrationNumber) != null)
      'registrationNumber': _trim(registrationNumber),
    if (_trim(businessAddress) != null)
      'businessAddress': _trim(businessAddress),
    if (_trim(authorizedRepName) != null)
      'authorizedRepName': _trim(authorizedRepName),
    if (_trim(authorizedRepPosition) != null)
      'authorizedRepPosition': _trim(authorizedRepPosition),
  };
}

class UpdateMerchantProfileRequest {
  final String? displayName;
  final String? bio;
  final String? country;
  final String? location;
  final String? email;
  final String? phone;
  final String? defaultCryptoAddress;
  final String? defaultCryptoMemo;
  final String? businessName;
  final String? registrationNumber;
  final String? businessAddress;
  final String? authorizedRepName;
  final String? authorizedRepPosition;

  const UpdateMerchantProfileRequest({
    this.displayName,
    this.bio,
    this.country,
    this.location,
    this.email,
    this.phone,
    this.defaultCryptoAddress,
    this.defaultCryptoMemo,
    this.businessName,
    this.registrationNumber,
    this.businessAddress,
    this.authorizedRepName,
    this.authorizedRepPosition,
  });

  static String? _trim(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    if (_trim(displayName) != null) 'displayName': _trim(displayName),
    if (_trim(bio) != null) 'bio': _trim(bio),
    if (_trim(country) != null) 'country': _trim(country),
    if (_trim(location) != null) 'location': _trim(location),
    if (_trim(email) != null) 'email': _trim(email),
    if (_trim(phone) != null) 'phone': _trim(phone),
    if (_trim(defaultCryptoAddress) != null)
      'defaultCryptoAddress': _trim(defaultCryptoAddress),
    if (_trim(defaultCryptoMemo) != null)
      'defaultCryptoMemo': _trim(defaultCryptoMemo),
    if (_trim(businessName) != null) 'businessName': _trim(businessName),
    if (_trim(registrationNumber) != null)
      'registrationNumber': _trim(registrationNumber),
    if (_trim(businessAddress) != null)
      'businessAddress': _trim(businessAddress),
    if (_trim(authorizedRepName) != null)
      'authorizedRepName': _trim(authorizedRepName),
    if (_trim(authorizedRepPosition) != null)
      'authorizedRepPosition': _trim(authorizedRepPosition),
  };
}

class UpdateMerchantAvailabilityRequest {
  final SellerAvailability availability;
  final bool? autoUnavailable;
  final DateTime? availableFrom;
  final DateTime? availableTo;

  const UpdateMerchantAvailabilityRequest({
    required this.availability,
    this.autoUnavailable,
    this.availableFrom,
    this.availableTo,
  });

  Map<String, dynamic> toJson() => {
    'availability': sellerAvailabilityToApi(availability),
    if (autoUnavailable != null) 'autoUnavailable': autoUnavailable,
    if (availableFrom != null)
      'availableFrom': availableFrom!.toIso8601String(),
    if (availableTo != null) 'availableTo': availableTo!.toIso8601String(),
  };
}
