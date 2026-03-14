class UpsertProfileRequest {
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_.]+$');

  final String? username;
  final String? displayName;
  final String? country;
  final bool includeNulls;

  const UpsertProfileRequest({
    this.username,
    this.displayName,
    this.country,
    this.includeNulls = false,
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

    return {
      if (includeNulls || username != null) 'username': normalizedUsername,
      if (includeNulls || displayName != null)
        'displayName': normalizedDisplayName,
      if (includeNulls || country != null) 'country': normalizedCountry,
    };
  }
}
