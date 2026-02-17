class ProfileModel {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? country;
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

    return ProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString(),
      displayName: json['displayName']?.toString(),
      country: json['country']?.toString(),
      firstName: json['firstName']?.toString(),
      middleName: json['middleName']?.toString(),
      lastName: json['lastName']?.toString(),
      address: json['address']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
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
