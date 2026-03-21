import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';

class PortfolioState {
  const PortfolioState({
    this.activeWalletId,
    this.activeWalletAddress,
    this.walletLabel,
    this.selectedRange = PortfolioRange.h24,
    this.data,
    this.loading = false,
    this.error,
    this.isOffline = false,
  });

  final String? activeWalletId;
  final String? activeWalletAddress;
  final String? walletLabel;
  final PortfolioRange selectedRange;
  final WalletPortfolioData? data;
  final bool loading;
  final String? error;
  final bool isOffline;

  bool get hasWallet =>
      (activeWalletId != null && activeWalletId!.trim().isNotEmpty) ||
      (activeWalletAddress != null && activeWalletAddress!.trim().isNotEmpty);
  bool get hasData => data != null;
  bool get isEmpty => !loading && error == null && data?.summary == null;
  bool get hasInsufficientData => (data?.chart.length ?? 0) < 2;
  bool get isZeroBalance => (data?.summary?.totalValue ?? 0) <= 0;

  PortfolioState copyWith({
    String? activeWalletId,
    String? activeWalletAddress,
    String? walletLabel,
    PortfolioRange? selectedRange,
    Object? data = _sentinel,
    bool? loading,
    Object? error = _sentinel,
    bool? isOffline,
  }) {
    return PortfolioState(
      activeWalletId: activeWalletId ?? this.activeWalletId,
      activeWalletAddress: activeWalletAddress ?? this.activeWalletAddress,
      walletLabel: walletLabel ?? this.walletLabel,
      selectedRange: selectedRange ?? this.selectedRange,
      data: identical(data, _sentinel) ? this.data : data as WalletPortfolioData?,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  static const Object _sentinel = Object();
}
