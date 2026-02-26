class RecipientWallet {
  final String id;
  final String userId;
  final String name;
  final String publicAddress;
  final String? address;
  final String? label;
  final String? colorTag;
  final String network;
  final String? memo;
  final String? memoType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipientWallet({
    required this.id,
    required this.userId,
    required this.name,
    required this.publicAddress,
    this.address,
    this.label,
    this.colorTag,
    required this.network,
    this.memo,
    this.memoType,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Backward-compatible aliases for existing UI code.
  String get displayName => name.trim().isNotEmpty ? name.trim() : (label ?? '').trim();
  String get effectiveAddress =>
      publicAddress.trim().isNotEmpty ? publicAddress : (address ?? '');

  factory RecipientWallet.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['label'] ?? '') as String;
    final rawPublicAddress =
        (json['publicAddress'] ?? json['address'] ?? '') as String;
    return RecipientWallet(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: rawName,
      publicAddress: rawPublicAddress,
      address: json['address'] as String?,
      label: json['label'] as String?,
      colorTag: (json['colorTag'] ?? json['color']) as String?,
      network: json['network'] as String? ?? 'stellar',
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
    'name': name,
    'publicAddress': publicAddress,
    if (address != null) 'address': address,
    if (label != null) 'label': label,
    if (colorTag != null) 'colorTag': colorTag,
    'network': network,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RecipientWallet copyWith({
    String? id,
    String? userId,
    String? name,
    String? publicAddress,
    String? address,
    String? label,
    String? colorTag,
    String? network,
    String? memo,
    String? memoType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipientWallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      publicAddress: publicAddress ?? this.publicAddress,
      address: address ?? this.address,
      label: label ?? this.label,
      colorTag: colorTag ?? this.colorTag,
      network: network ?? this.network,
      memo: memo ?? this.memo,
      memoType: memoType ?? this.memoType,
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
  final String? colorTag;
  final bool? isActive;
  final String? memo;
  final String? memoType;

  const CreateRecipientWalletRequest({
    required this.name,
    required this.publicAddress,
    this.network,
    this.colorTag,
    this.isActive,
    this.memo,
    this.memoType,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'publicAddress': publicAddress,
    if (network != null) 'network': network,
    if (colorTag != null) 'colorTag': colorTag,
    if (isActive != null) 'isActive': isActive,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
  };
}

class UpdateRecipientWalletRequest {
  final String? name;
  final String? publicAddress;
  final String? network;
  final String? colorTag;
  final bool? isActive;
  final String? memo;
  final String? memoType;

  const UpdateRecipientWalletRequest({
    this.name,
    this.publicAddress,
    this.network,
    this.colorTag,
    this.isActive,
    this.memo,
    this.memoType,
  });

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (publicAddress != null) 'publicAddress': publicAddress,
    if (network != null) 'network': network,
    if (colorTag != null) 'colorTag': colorTag,
    if (isActive != null) 'isActive': isActive,
    if (memo != null) 'memo': memo,
    if (memoType != null) 'memoType': memoType,
  };
}
