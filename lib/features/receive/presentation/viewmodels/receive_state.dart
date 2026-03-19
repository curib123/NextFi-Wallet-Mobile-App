// lib/features/receive/model/receive_state.dart
class ReceiveState {
  final String address;
  final String assetSymbol;

  const ReceiveState({
    required this.address,
    required this.assetSymbol,
  });

  ReceiveState copyWith({
    String? address,
    String? assetSymbol,
  }) {
    return ReceiveState(
      address: address ?? this.address,
      assetSymbol: assetSymbol ?? this.assetSymbol,
    );
  }
}
