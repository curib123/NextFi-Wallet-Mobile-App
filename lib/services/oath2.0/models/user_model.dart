class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String provider;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.provider,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    provider: json['provider'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'avatarUrl': avatarUrl,
    'provider': provider,
  };
}