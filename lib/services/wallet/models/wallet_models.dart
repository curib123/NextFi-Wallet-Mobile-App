class WalletAddress {
  final String id;
  final String publicAddress;
  final String network;
  final String? label;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletAddress({
    required this.id,
    required this.publicAddress,
    this.network = 'stellar',
    this.label,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletAddress.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v == 'true' || v == '1') return true;
          if (v == 'false' || v == '0') return false;
        }
      }
      return fallback;
    }

    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    return WalletAddress(
      id: readString(const ['id']),
      publicAddress: readString(const [
        'publicAddress',
        'public_address',
        'address',
      ]),
      network: readString(const ['network'], fallback: 'stellar'),
      label: (() {
        final text = readString(const ['label', 'name']);
        return text.isEmpty ? null : text;
      })(),
      isActive: readBool(const ['isActive', 'is_active']),
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
      total: readInt(const ['total', 'count']),
      page: readInt(const ['page'], fallback: 1),
      limit: readInt(const ['limit', 'pageSize', 'page_size'], fallback: 20),
      totalPages: readInt(const ['totalPages', 'total_pages'], fallback: 1),
    );
  }
}

class WalletPagedResponse {
  final List<WalletAddress> items;
  final WalletPaginationMeta meta;

  const WalletPagedResponse({required this.items, required this.meta});
}
