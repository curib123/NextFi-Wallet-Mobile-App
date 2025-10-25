class AccountState {
  final double xlm;
  final double usdc;
  final bool hasUsdcTrustline;
  final DateTime updatedAt;
  const AccountState({
    required this.xlm,
    required this.usdc,
    required this.hasUsdcTrustline,
    required this.updatedAt,
  });
}

class FeeEstimate {
  final int perOpStroops;
  final int totalStroops;
  final double totalXlm;
  final int baseFee;
  final int opCount;
  final int percentile;
  final DateTime ledgerClosedAt;
  const FeeEstimate({
    required this.perOpStroops,
    required this.totalStroops,
    required this.totalXlm,
    required this.baseFee,
    required this.opCount,
    required this.percentile,
    required this.ledgerClosedAt,
  });
}

class PairPrice {
  final double usdcPerXlm; // counter/base = USDC per 1 XLM
  double get xlmPerUsdc => usdcPerXlm == 0 ? 0 : 1 / usdcPerXlm;
  final DateTime at;
  const PairPrice(this.usdcPerXlm, this.at);
}
