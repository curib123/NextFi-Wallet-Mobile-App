// lib/features/receive/model/receive_state.dart
class ReceiveState {
  final String address;
  final double xlmBalance;
  final double usdcBalance;
  final bool xlmSelected; // true => XLM, false => USDC

  const ReceiveState({
    required this.address,
    required this.xlmBalance,
    required this.usdcBalance,
    this.xlmSelected = true,
  });

  String get token => xlmSelected ? 'XLM' : 'USDC';

  ReceiveState copyWith({
    String? address,
    double? xlmBalance,
    double? usdcBalance,
    bool? xlmSelected,
  }) {
    return ReceiveState(
      address: address ?? this.address,
      xlmBalance: xlmBalance ?? this.xlmBalance,
      usdcBalance: usdcBalance ?? this.usdcBalance,
      xlmSelected: xlmSelected ?? this.xlmSelected,
    );
  }
}
