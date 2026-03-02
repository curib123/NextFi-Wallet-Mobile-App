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

  static String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is String) return v;
    return v.toString();
  }

  static DateTime _asDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.parse(v);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory RecipientWallet.fromJson(Map<String, dynamic> json) {
    final rawName = _asString(json['name'] ?? json['label']);
    final rawPublicAddress = _asString(json['publicAddress'] ?? json['address']);
    return RecipientWallet(
      id: _asString(json['id']),
      userId: _asString(json['userId']),
      name: rawName,
      publicAddress: rawPublicAddress,
      address: json['address'] == null ? null : _asString(json['address']),
      label: json['label'] == null ? null : _asString(json['label']),
      colorTag: (json['colorTag'] ?? json['color']) == null
          ? null
          : _asString(json['colorTag'] ?? json['color']),
      network: _asString(json['network'], fallback: 'stellar'),
      memo: json['memo'] == null ? null : _asString(json['memo']),
      memoType: json['memoType'] == null ? null : _asString(json['memoType']),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
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
