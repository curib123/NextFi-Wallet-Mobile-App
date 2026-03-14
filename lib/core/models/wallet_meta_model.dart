/// Minimal metadata per wallet (top-level type).
class WalletMetaModel {
  final String id;
  String name;
  String createdAt;
  String? lastUsedAt;
  String? publicAddress; // optional hint for UI

  WalletMetaModel({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    this.publicAddress,
  });

  factory WalletMetaModel.fromJson(Map<String, dynamic> j) => WalletMetaModel(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: j['createdAt'] as String,
    lastUsedAt: j['lastUsedAt'] as String?,
    publicAddress: j['publicAddress'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt,
    'lastUsedAt': lastUsedAt,
    'publicAddress': publicAddress,
  };
}