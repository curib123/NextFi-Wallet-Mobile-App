class WalletAddress {
  final String id;
  final String publicAddress;
  final String network;
  final String? label;
  final String? lastCursor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WalletAddress({
    required this.id,
    required this.publicAddress,
    required this.network,
    this.label,
    this.lastCursor,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletAddress.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return WalletAddress(
      id: json['id'].toString(),
      publicAddress: json['publicAddress'].toString(),
      network: (json['network'] ?? 'stellar').toString(),
      label: json['label']?.toString(),
      lastCursor: json['lastCursor']?.toString(),
      createdAt: _dt(json['createdAt']),
      updatedAt: _dt(json['updatedAt']),
    );
  }
}
