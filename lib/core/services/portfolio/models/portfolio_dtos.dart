class PortfolioSnapshotAssetRequest {
  const PortfolioSnapshotAssetRequest({
    required this.code,
    required this.issuer,
    required this.balance,
    required this.price,
    required this.fiatValue,
    required this.allocationPercent,
  });

  final String code;
  final String? issuer;
  final double balance;
  final double price;
  final double fiatValue;
  final double allocationPercent;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'issuer': issuer,
      'balance': balance,
      'price': price,
      'fiatValue': fiatValue,
      'allocationPercent': allocationPercent,
    };
  }
}

class CreatePortfolioSnapshotRequest {
  const CreatePortfolioSnapshotRequest({
    required this.walletId,
    required this.walletAddress,
    required this.timestamp,
    required this.trigger,
    required this.dedupeKey,
    required this.assets,
    required this.totalValue,
    required this.fiatCurrency,
    this.appVersion,
  });

  final String walletId;
  final String walletAddress;
  final DateTime timestamp;
  final String trigger;
  final String dedupeKey;
  final List<PortfolioSnapshotAssetRequest> assets;
  final double totalValue;
  final String fiatCurrency;
  final String? appVersion;

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'walletAddress': walletAddress,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'trigger': trigger,
      'dedupeKey': dedupeKey,
      'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
      'totalValue': totalValue,
      'fiatCurrency': fiatCurrency,
      'appVersion': appVersion,
    };
  }
}
