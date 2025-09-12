// lib/features/wallet_home/model/wallet_home_state.dart
import 'incoming_hint.dart';

class WalletHomeState {
  final String? address;
  final String? walletName;

  final double xlm;
  final double usdc;

  final bool loadingWallet;
  final bool loadingBalances;

  final DateTime? lastBalancesAt;

  final List<IncomingHint> hints;

  const WalletHomeState({
    this.address,
    this.walletName,
    this.xlm = 0,
    this.usdc = 0,
    this.loadingWallet = false,
    this.loadingBalances = false,
    this.lastBalancesAt,
    this.hints = const [],
  });

  bool get hasWallet => (address != null && address!.isNotEmpty);

  WalletHomeState copyWith({
    String? address,
    String? walletName,
    double? xlm,
    double? usdc,
    bool? loadingWallet,
    bool? loadingBalances,
    DateTime? lastBalancesAt,
    List<IncomingHint>? hints,
  }) {
    return WalletHomeState(
      address: address ?? this.address,
      walletName: walletName ?? this.walletName,
      xlm: xlm ?? this.xlm,
      usdc: usdc ?? this.usdc,
      loadingWallet: loadingWallet ?? this.loadingWallet,
      loadingBalances: loadingBalances ?? this.loadingBalances,
      lastBalancesAt: lastBalancesAt ?? this.lastBalancesAt,
      hints: hints ?? this.hints,
    );
  }
}
