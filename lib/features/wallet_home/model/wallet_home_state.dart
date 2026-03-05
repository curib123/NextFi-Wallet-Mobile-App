// lib/features/wallet_home/model/wallet_home_state.dart
import 'incoming_hint.dart';

enum PriceWindow { h24, d7, d30, y1 }

class WalletHomeState {
  final String? address;
  final String? walletName;

  // Spendable balances (XLM reserve already excluded).
  final double xlm;
  final double usdc;

  // Reserve balance tracking
  final double xlmBaseReserve;
  final double xlmTrustlineReserve;
  final double xlmTotalReserve;
  final int trustlineCount;

  final bool loadingWallet;
  final bool loadingBalances;
  final bool loadingReserves;

  final DateTime? lastBalancesAt;
  final DateTime? lastReservesAt;

  final List<IncomingHint> hints;

  final PriceWindow selectedWindow;

  const WalletHomeState({
    this.address,
    this.walletName,
    this.xlm = 0,
    this.usdc = 0,
    this.xlmBaseReserve = 1.0,
    this.xlmTrustlineReserve = 0.0,
    this.xlmTotalReserve = 1.0,
    this.trustlineCount = 0,
    this.loadingWallet = false,
    this.loadingBalances = false,
    this.loadingReserves = false,
    this.lastBalancesAt,
    this.lastReservesAt,
    this.hints = const [],
    this.selectedWindow = PriceWindow.h24,
  });

  bool get hasWallet => (address != null && address!.isNotEmpty);

  // `xlm` is already spendable (total - reserve - liabilities).
  double get spendableXlm => xlm;

  double get totalLockedReserve => xlmTotalReserve;

  WalletHomeState copyWith({
    String? address,
    String? walletName,
    double? xlm,
    double? usdc,
    double? xlmBaseReserve,
    double? xlmTrustlineReserve,
    double? xlmTotalReserve,
    int? trustlineCount,
    bool? loadingWallet,
    bool? loadingBalances,
    bool? loadingReserves,
    DateTime? lastBalancesAt,
    DateTime? lastReservesAt,
    List<IncomingHint>? hints,
    PriceWindow? selectedWindow,
  }) {
    return WalletHomeState(
      address: address ?? this.address,
      walletName: walletName ?? this.walletName,
      xlm: xlm ?? this.xlm,
      usdc: usdc ?? this.usdc,
      xlmBaseReserve: xlmBaseReserve ?? this.xlmBaseReserve,
      xlmTrustlineReserve: xlmTrustlineReserve ?? this.xlmTrustlineReserve,
      xlmTotalReserve: xlmTotalReserve ?? this.xlmTotalReserve,
      trustlineCount: trustlineCount ?? this.trustlineCount,
      loadingWallet: loadingWallet ?? this.loadingWallet,
      loadingBalances: loadingBalances ?? this.loadingBalances,
      loadingReserves: loadingReserves ?? this.loadingReserves,
      lastBalancesAt: lastBalancesAt ?? this.lastBalancesAt,
      lastReservesAt: lastReservesAt ?? this.lastReservesAt,
      hints: hints ?? this.hints,
      selectedWindow: selectedWindow ?? this.selectedWindow,
    );
  }
}
