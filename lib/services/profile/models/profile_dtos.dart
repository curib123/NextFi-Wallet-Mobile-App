import 'profile_models.dart';

class UpsertProfileRequest {
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_.]+$');

  final String? username;
  final String? displayName;
  final String? country;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? address;

  final ProfileAvailability? availability;
  final bool? isActive;
  final bool? autoUnavailable;
  final DateTime? availableFrom;
  final DateTime? availableTo;

  const UpsertProfileRequest({
    this.username,
    this.displayName,
    this.country,
    this.firstName,
    this.middleName,
    this.lastName,
    this.address,
    this.availability,
    this.isActive,
    this.autoUnavailable,
    this.availableFrom,
    this.availableTo,
  });

  static String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeUsername(String? value) {
    final normalized = _normalizeText(value);
    return normalized?.toLowerCase();
  }

  static bool isValidUsername(String value) {
    final normalized = value.trim();
    return normalized.length >= 3 &&
        normalized.length <= 30 &&
        usernamePattern.hasMatch(normalized);
  }

  Map<String, dynamic> toJson() {
    final normalizedUsername = _normalizeUsername(username);
    final normalizedDisplayName = _normalizeText(displayName);
    final normalizedCountry = _normalizeText(country);
    final normalizedFirstName = _normalizeText(firstName);
    final normalizedMiddleName = _normalizeText(middleName);
    final normalizedLastName = _normalizeText(lastName);
    final normalizedAddress = _normalizeText(address);

    return {
      if (normalizedUsername != null) 'username': normalizedUsername,
      if (normalizedDisplayName != null) 'displayName': normalizedDisplayName,
      if (normalizedCountry != null) 'country': normalizedCountry,
      if (normalizedFirstName != null) 'firstName': normalizedFirstName,
      if (normalizedMiddleName != null) 'middleName': normalizedMiddleName,
      if (normalizedLastName != null) 'lastName': normalizedLastName,
      if (normalizedAddress != null) 'address': normalizedAddress,
      if (availability != null)
        'availability': profileAvailabilityToApi(availability!),
      if (isActive != null) 'isActive': isActive,
      if (autoUnavailable != null) 'autoUnavailable': autoUnavailable,
      if (availableFrom != null)
        'availableFrom': availableFrom!.toIso8601String(),
      if (availableTo != null) 'availableTo': availableTo!.toIso8601String(),
    };
  }
}

class RequestMerchantAccessRequest {
  final String? note;

  const RequestMerchantAccessRequest({this.note});

  Map<String, dynamic> toJson() {
    final normalized = note?.trim();
    return {
      if (normalized != null && normalized.isNotEmpty) 'note': normalized,
    };
  }
}
