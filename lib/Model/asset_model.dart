class AssetModel {
  final String id;
  final String name;
  final String symbol;
  final String coingeckoId;
  double priceChangePercent24h; // real-time up/down percent

  AssetModel({
    required this.id,
    required this.name,
    required this.symbol,
    required this.coingeckoId,
    this.priceChangePercent24h = 0.0,
  });

  /// Create an AssetModel from JSON
  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
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
      'coingeckoId': coingeckoId,
      'priceChangePercent24h': priceChangePercent24h,
    };
  }

  /// Update price change percent safely
  void setPriceChangePercent(double percent) {
    priceChangePercent24h = percent;
  }
}
