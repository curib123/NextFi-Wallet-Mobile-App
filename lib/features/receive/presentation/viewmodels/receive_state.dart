// lib/features/receive/model/receive_state.dart
class ReceiveState {
  final String address;
  final String token;

  const ReceiveState({
    required this.address,
    required this.token,
  });

  ReceiveState copyWith({
    String? address,
    String? token,
  }) {
    return ReceiveState(
      address: address ?? this.address,
      token: token ?? this.token,
    );
  }
}
