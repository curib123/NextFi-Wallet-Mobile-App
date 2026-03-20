class IncomingHint {
  final String id;
  final String from;
  final String to;
  final String assetCode;
  final double amount;
  final DateTime at;
  const IncomingHint({
    required this.id,
    required this.from,
    required this.to,
    required this.assetCode,
    required this.amount,
    required this.at,
  });
}
