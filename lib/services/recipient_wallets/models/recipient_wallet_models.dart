class RecipientWallet {
  final String id;
  final String userId;
  final String name;
  final String publicAddress;
  final String network;
  final String? memo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipientWallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.publicAddress,
    required this.network,
    this.memo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipientWallet.fromJson(Map<String, dynamic> json) {
    return RecipientWallet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      publicAddress: json['publicAddress'] as String,
      network: json['network'] as String? ?? 'stellar',
      memo: json['memo'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'publicAddress': publicAddress,
    'network': network,
    if (memo != null) 'memo': memo,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RecipientWallet copyWith({
    String? id,
    String? userId,
    String? name,
    String? publicAddress,
    String? network,
    String? memo,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipientWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      publicAddress: publicAddress ?? this.publicAddress,
      network: network ?? this.network,
      memo: memo ?? this.memo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreateRecipientWalletRequest {
  final String name;
  final String publicAddress;
  final String? network;
  final String? memo;
  final bool? isActive;

  const CreateRecipientWalletRequest({
    required this.name,
    required this.publicAddress,
    this.network,
    this.memo,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'publicAddress': publicAddress,
    if (network != null) 'network': network,
    if (memo != null) 'memo': memo,
    if (isActive != null) 'isActive': isActive,
  };
}

class UpdateRecipientWalletRequest {
  final String? name;
  final String? publicAddress;
  final String? network;
  final String? memo;
  final bool? isActive;

  const UpdateRecipientWalletRequest({
    this.name,
    this.publicAddress,
    this.network,
    this.memo,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (publicAddress != null) 'publicAddress': publicAddress,
    if (network != null) 'network': network,
    if (memo != null) 'memo': memo,
    if (isActive != null) 'isActive': isActive,
  };
}