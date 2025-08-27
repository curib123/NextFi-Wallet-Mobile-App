class AssetModel {
  final String id;
  final String name;
  final String symbol;
  double balance;
  final String coingeckoId;
  double priceChangePercent24h; // real-time up/down percent

  AssetModel({
    required this.id,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.coingeckoId,
    this.priceChangePercent24h = 0.0,
  });

  /// Create an AssetModel from JSON
  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      coingeckoId: json['coingeckoId'] ?? '',
      priceChangePercent24h: (json['priceChangePercent24h'] ?? 0).toDouble(),
    );
  }

  /// Convert AssetModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'balance': balance,
      'coingeckoId': coingeckoId,
      'priceChangePercent24h': priceChangePercent24h,
    };
  }

  /// Update balance safely
  void updateBalance(double amount) {
    balance += amount;
  }

  /// Set balance directly
  void setBalance(double amount) {
    balance = amount;
  }

  /// Update price change percent safely
  void setPriceChangePercent(double percent) {
    priceChangePercent24h = percent;
  }
}
