class UpsertProfileRequest {
  final String? username;
  final String? displayName;
  final String? country;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? address;

  const UpsertProfileRequest({
    this.username,
    this.displayName,
    this.country,
    this.firstName,
    this.middleName,
    this.lastName,
    this.address,
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
    };
  }
}
