class FeeConfigModel {
  FeeConfigModel({
    required this.profitAddress,
    required this.txFeeUsd,
    required this.swapFeePercent,
    required this.isEnabled,
    this.updatedAt,
  });

  final String profitAddress;
  final double txFeeUsd;
  final double swapFeePercent;
  final bool isEnabled;
  final DateTime? updatedAt;

  double get swapFeeRate => (swapFeePercent / 100).clamp(0.0, 1.0);

  factory FeeConfigModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    return FeeConfigModel(
      profitAddress: (json['profitAddress'] ?? '').toString().trim(),
      txFeeUsd: (json['txFeeUsd'] as num?)?.toDouble() ?? 0.0,
      swapFeePercent: (json['swapFeePercent'] as num?)?.toDouble() ?? 0.0,
      isEnabled: json['isEnabled'] == true,
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
