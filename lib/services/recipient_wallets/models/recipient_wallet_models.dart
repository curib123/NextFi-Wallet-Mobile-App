class RecipientWallet {
  final String id;
  final String userId;
  final String address;
  final String network;
  final String? label;
  final String? memo;
  final String? memoType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipientWallet({
    required this.id,
    required this.userId,
    required this.address,
    required this.network,
    this.label,
    this.memo,
    this.memoType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Backward-compatible aliases for existing UI code.
  String get name => (label ?? '').trim();
  String get publicAddress => address;

  factory RecipientWallet.fromJson(Map<String, dynamic> json) {
    return RecipientWallet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      address: (json['address'] ?? json['publicAddress'] ?? '') as String,
      network: json['network'] as String? ?? 'stellar',
      label: (json['label'] ?? json['name']) as String?,
      memo: json['memo'] as String?,
      memoType: json['memoType'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'address': address,
    'network': network,
    if (label != null) 'label': label,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RecipientWallet copyWith({
    String? id,
    String? userId,
    String? address,
    String? network,
    String? label,
    String? memo,
    String? memoType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipientWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      address: address ?? this.address,
      network: network ?? this.network,
      label: label ?? this.label,
      memo: memo ?? this.memo,
      memoType: memoType ?? this.memoType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreateRecipientWalletRequest {
  final String address;
  final String? network;
  final String? label;
  final String? memo;
  final String? memoType;

  const CreateRecipientWalletRequest({
    required this.address,
    this.network,
    this.label,
    this.memo,
    this.memoType,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    if (network != null) 'network': network,
    if (label != null) 'label': label,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
  };
}

class UpdateRecipientWalletRequest {
  final String? address;
  final String? network;
  final String? label;
  final String? memo;
  final String? memoType;

  const UpdateRecipientWalletRequest({
    this.address,
    this.network,
    this.label,
    this.memo,
    this.memoType,
  });

  Map<String, dynamic> toJson() => {
    if (address != null) 'address': address,
    if (network != null) 'network': network,
    if (label != null) 'label': label,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
  };
}
