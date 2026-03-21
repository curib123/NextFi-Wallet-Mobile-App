import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';

class PortfolioState {
  const PortfolioState({
    this.activeWalletId,
    this.activeWalletAddress,
    this.walletLabel,
    this.selectedRange = PortfolioRange.h24,
    this.data,
    this.loading = false,
    this.refreshing = false,
    this.capturingSnapshot = false,
    this.error,
    this.lastLoadedWalletId,
  });

  final String? activeWalletId;
  final String? activeWalletAddress;
  final String? walletLabel;
  final PortfolioRange selectedRange;
  final WalletPortfolioData? data;
  final bool loading;
  final bool refreshing;
  final bool capturingSnapshot;
  final String? error;
  final String? lastLoadedWalletId;

  bool get hasWallet =>
      (activeWalletId ?? '').trim().isNotEmpty &&
      (activeWalletAddress ?? '').trim().isNotEmpty;

  bool get hasData => data != null;
  bool get isEmpty => !loading && data?.summary == null && !(isZeroBalance);
  bool get isZeroBalance =>
      !loading &&
      (data?.summary?.totalValue ?? 0) <= 0 &&
      (data?.allocation.isEmpty ?? true);
  bool get hasInsufficientData => !loading && (data?.chart.length ?? 0) == 1;
  bool get isOffline => error?.toLowerCase().contains('socket') == true;

  PortfolioState copyWith({
    String? activeWalletId,
    String? activeWalletAddress,
    String? walletLabel,
    PortfolioRange? selectedRange,
    WalletPortfolioData? data,
    bool? loading,
    bool? refreshing,
    bool? capturingSnapshot,
    String? error,
    bool clearError = false,
    bool clearData = false,
    String? lastLoadedWalletId,
  }) {
    return PortfolioState(
      activeWalletId: activeWalletId ?? this.activeWalletId,
      activeWalletAddress: activeWalletAddress ?? this.activeWalletAddress,
      walletLabel: walletLabel ?? this.walletLabel,
      selectedRange: selectedRange ?? this.selectedRange,
      data: clearData ? null : (data ?? this.data),
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      capturingSnapshot: capturingSnapshot ?? this.capturingSnapshot,
      error: clearError ? null : (error ?? this.error),
      lastLoadedWalletId: lastLoadedWalletId ?? this.lastLoadedWalletId,
    );
  }

  factory PortfolioState.initial() => const PortfolioState();
}
