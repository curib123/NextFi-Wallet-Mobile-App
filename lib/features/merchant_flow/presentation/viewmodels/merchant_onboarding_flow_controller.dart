import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/core/services/merchant_profile/merchant_onboarding_flow_service.dart';
import 'package:next_fi/features/merchant_flow/presentation/viewmodels/merchant_onboarding_flow_state.dart';

final merchantOnboardingFlowServiceProvider =
    Provider<MerchantOnboardingFlowService>(
      (Ref ref) => MerchantOnboardingFlowService.I,
    );

final merchantOnboardingFlowControllerProvider =
    NotifierProvider.autoDispose<
      MerchantOnboardingFlowController,
      MerchantOnboardingFlowState
    >(MerchantOnboardingFlowController.new);

class MerchantOnboardingFlowController
    extends Notifier<MerchantOnboardingFlowState> {
  @override
  MerchantOnboardingFlowState build() {
    Future<void>.microtask(load);
    return const MerchantOnboardingFlowState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final snapshot = await ref
          .read(merchantOnboardingFlowServiceProvider)
          .getSnapshot();
      if (!ref.mounted) return;
      state = state.copyWith(snapshot: snapshot, loading: false, error: null);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }
}
