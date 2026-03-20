import 'package:next_fi/features/swap/data/models/swap_dir.dart';

const Object _noChange = Object();

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
    Object? error = _noChange,
    Object? accountId = _noChange,
    double? xlmBal,
    double? usdcBal,
    Object? estReceive = _noChange,
    Object? feeXlm = _noChange,
    bool? needsTrustline,
    SwapDir? dir,
  }) {
    return SwapState(
      loading: loading ?? this.loading,
      error: identical(error, _noChange) ? this.error : error as String?,
      accountId: identical(accountId, _noChange)
          ? this.accountId
          : accountId as String?,
      xlmBal: xlmBal ?? this.xlmBal,
      usdcBal: usdcBal ?? this.usdcBal,
      estReceive: identical(estReceive, _noChange)
          ? this.estReceive
          : estReceive as double?,
      feeXlm: identical(feeXlm, _noChange) ? this.feeXlm : feeXlm as double?,
      needsTrustline: needsTrustline ?? this.needsTrustline,
      dir: dir ?? this.dir,
    );
  }
}
