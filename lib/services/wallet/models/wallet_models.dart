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
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    String? readNullableString(List<String> keys) {
      final value = readString(keys);
      return value.isEmpty ? null : value;
    }

    return WalletAddress(
      id: readString(const ['id', 'walletId', 'wallet_id']),
      publicAddress: readString(const [
        'publicAddress',
        'public_address',
        'address',
      ]),
      network: readString(const ['network'], fallback: 'stellar'),
      label: readNullableString(const ['label']),
      lastCursor: readNullableString(const ['lastCursor', 'last_cursor']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class WalletPaginationMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const WalletPaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory WalletPaginationMeta.fromJson(Map<String, dynamic> json) {
    int readInt(List<String> keys, {int fallback = 0}) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    return WalletPaginationMeta(
      total: readInt(const ['total']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class WalletPagedResponse {
  final List<WalletAddress> items;
  final WalletPaginationMeta meta;

  const WalletPagedResponse({required this.items, required this.meta});
}
