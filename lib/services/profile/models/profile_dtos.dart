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

  Map<String, dynamic> toJson() => {
        if (username != null) 'username': username,
        if (displayName != null) 'displayName': displayName,
        if (country != null) 'country': country,
        if (firstName != null) 'firstName': firstName,
        if (middleName != null) 'middleName': middleName,
        if (lastName != null) 'lastName': lastName,
        if (address != null) 'address': address,
      };
}
