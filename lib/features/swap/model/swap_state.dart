// lib/features/swap/model/swap_state.dart
import 'swap_dir.dart';

class SwapState {
  final bool loading;
  final String? error;

  final String? accountId;
  final double xlmBal;
  final double usdcBal;

  final double? estReceive;
  final double? feeXlm;
  final bool needsTrustline;

  final SwapDir dir;

  const SwapState({
    this.loading = true,
    this.error,
    this.accountId,
    this.xlmBal = 0.0,
    this.usdcBal = 0.0,
    this.estReceive,
    this.feeXlm,
    this.needsTrustline = false,
    this.dir = SwapDir.xlmToUsdc,
  });

  bool get isXlmToUsdc => dir == SwapDir.xlmToUsdc;

  SwapState copyWith({
    bool? loading,
    String? error,
    String? accountId,
    double? xlmBal,
    double? usdcBal,
    double? estReceive,
    double? feeXlm,
    bool? needsTrustline,
    SwapDir? dir,
  }) {
    return SwapState(
      loading: loading ?? this.loading,
      error: error,
      accountId: accountId ?? this.accountId,
      xlmBal: xlmBal ?? this.xlmBal,
      usdcBal: usdcBal ?? this.usdcBal,
      estReceive: estReceive,
      feeXlm: feeXlm,
      needsTrustline: needsTrustline ?? this.needsTrustline,
      dir: dir ?? this.dir,
    );
  }
}
