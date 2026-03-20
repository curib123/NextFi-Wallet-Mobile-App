class ProfileModel {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? country;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.country,
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

    return ProfileModel(
      id: readString(const ['id']) ?? '',
      userId: readString(const ['userId', 'user_id']) ?? '',
      username: readString(const ['username']),
      displayName: readString(const ['displayName', 'display_name']),
      country: readString(const ['country']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  bool get isVerificationIdentityComplete {
    bool hasValue(String? value) => value != null && value.trim().isNotEmpty;
    return hasValue(username);
  }
}
