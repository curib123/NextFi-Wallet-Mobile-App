import 'package:next_fi/core/services/merchant_profile/merchant_onboarding_flow_service.dart';

const Object _sentinel = Object();

class MerchantOnboardingFlowState {
  const MerchantOnboardingFlowState({
    this.snapshot,
    this.error,
    this.loading = true,
  });

  final MerchantOnboardingSnapshot? snapshot;
  final String? error;
  final bool loading;

  MerchantOnboardingFlowState copyWith({
    MerchantOnboardingSnapshot? snapshot,
    Object? error = _sentinel,
    bool? loading,
  }) {
    return MerchantOnboardingFlowState(
      snapshot: snapshot ?? this.snapshot,
      error: identical(error, _sentinel) ? this.error : error as String?,
      loading: loading ?? this.loading,
    );
  }
}
