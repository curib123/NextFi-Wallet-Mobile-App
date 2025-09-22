import 'dart:convert';

enum SwapOrderSide { xlmToUsdc, usdcToXlm }

class SwapOrder {
  final String id;
  final SwapOrderSide side;
  final double amountFrom;
  final double slippagePct;           // 0.01 = 1%
  final double? limitPriceUsdcPerXlm; // optional (limit order)
  final DateTime? scheduleAt;         // optional (schedule order)
  final DateTime createdAt;

  final bool active;                  // false = executed/canceled
  final String? txId;
  final DateTime? executedAt;
  final String? lastError;

  const SwapOrder({
    required this.id,
    required this.side,
    required this.amountFrom,
    required this.slippagePct,
    required this.createdAt,
    this.limitPriceUsdcPerXlm,
    this.scheduleAt,
    this.active = true,
    this.txId,
    this.executedAt,
    this.lastError,
  });

  SwapOrder copyWith({
    bool? active,
    String? txId,
    DateTime? executedAt,
    String? lastError,
  }) => SwapOrder(
    id: id,
    side: side,
    amountFrom: amountFrom,
    slippagePct: slippagePct,
    limitPriceUsdcPerXlm: limitPriceUsdcPerXlm,
    scheduleAt: scheduleAt,
    createdAt: createdAt,
    active: active ?? this.active,
    txId: txId ?? this.txId,
    executedAt: executedAt ?? this.executedAt,
    lastError: lastError ?? this.lastError,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'side': side.name,
    'amountFrom': amountFrom,
    'slippagePct': slippagePct,
    'limitPriceUsdcPerXlm': limitPriceUsdcPerXlm,
    'scheduleAt': scheduleAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'active': active,
    'txId': txId,
    'executedAt': executedAt?.toIso8601String(),
    'lastError': lastError,
  };

  factory SwapOrder.fromMap(Map<String, dynamic> m) => SwapOrder(
    id: m['id'] as String,
    side: SwapOrderSide.values.firstWhere((e) => e.name == m['side']),
    amountFrom: (m['amountFrom'] as num).toDouble(),
    slippagePct: (m['slippagePct'] as num).toDouble(),
    limitPriceUsdcPerXlm: (m['limitPriceUsdcPerXlm'] as num?)?.toDouble(),
    scheduleAt: m['scheduleAt'] != null ? DateTime.parse(m['scheduleAt']) : null,
    createdAt: DateTime.parse(m['createdAt']),
    active: m['active'] as bool? ?? true,
    txId: m['txId'] as String?,
    executedAt: m['executedAt'] != null ? DateTime.parse(m['executedAt']) : null,
    lastError: m['lastError'] as String?,
  );

  String toJson() => jsonEncode(toMap());
  factory SwapOrder.fromJson(String s) => SwapOrder.fromMap(jsonDecode(s));
}
