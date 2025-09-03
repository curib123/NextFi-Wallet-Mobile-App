class AssetModel {
  final String id;
  final String name;
  final String symbol;

  double priceChangePercent24h;   // real-time up/down percent
  double priceChangePercent7d;    // 1 week
  double priceChangePercent30d;   // 1 month
  double priceChangePercent1y;    // 1 year

  AssetModel({
    required this.id,
    required this.name,
    required this.symbol,
    this.priceChangePercent24h = 0.0,
    this.priceChangePercent7d = 0.0,
    this.priceChangePercent30d = 0.0,
    this.priceChangePercent1y = 0.0,
  });

  /// Create an AssetModel from JSON
  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      priceChangePercent24h: (json['priceChangePercent24h'] ?? 0).toDouble(),
      priceChangePercent7d: (json['priceChangePercent7d'] ?? 0).toDouble(),
      priceChangePercent30d: (json['priceChangePercent30d'] ?? 0).toDouble(),
      priceChangePercent1y: (json['priceChangePercent1y'] ?? 0).toDouble(),
    );
  }

  /// Convert AssetModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'priceChangePercent24h': priceChangePercent24h,
      'priceChangePercent7d': priceChangePercent7d,
      'priceChangePercent30d': priceChangePercent30d,
      'priceChangePercent1y': priceChangePercent1y,
    };
  }

  /// Update price change percents safely
  void setPriceChangePercent({
    double? percent24h,
    double? percent7d,
    double? percent30d,
    double? percent1y,
  }) {
    if (percent24h != null) priceChangePercent24h = percent24h;
    if (percent7d != null) priceChangePercent7d = percent7d;
    if (percent30d != null) priceChangePercent30d = percent30d;
    if (percent1y != null) priceChangePercent1y = percent1y;
  }
}
