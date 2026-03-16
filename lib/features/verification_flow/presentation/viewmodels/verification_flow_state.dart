import 'package:next_fi/core/services/verification/verification_flow_service.dart';

const Object _sentinel = Object();

class VerificationFlowState {
  const VerificationFlowState({this.snapshot, this.error, this.loading = true});

  final VerificationFlowSnapshot? snapshot;
  final String? error;
  final bool loading;

  VerificationFlowState copyWith({
    VerificationFlowSnapshot? snapshot,
    Object? error = _sentinel,
    bool? loading,
  }) {
    return VerificationFlowState(
      snapshot: snapshot ?? this.snapshot,
      error: identical(error, _sentinel) ? this.error : error as String?,
      loading: loading ?? this.loading,
    );
  }
}
