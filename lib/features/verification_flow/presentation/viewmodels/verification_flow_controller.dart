import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/core/services/verification/verification_flow_service.dart';
import 'package:next_fi/features/verification_flow/presentation/viewmodels/verification_flow_state.dart';

final verificationFlowServiceProvider = Provider<VerificationFlowService>(
  (Ref ref) => VerificationFlowService.I,
);

final verificationFlowControllerProvider =
    NotifierProvider.autoDispose<
      VerificationFlowController,
      VerificationFlowState
    >(VerificationFlowController.new);

class VerificationFlowController extends Notifier<VerificationFlowState> {
  @override
  VerificationFlowState build() {
    Future<void>.microtask(load);
    return const VerificationFlowState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final snapshot = await ref
          .read(verificationFlowServiceProvider)
          .getSnapshot();
      if (!ref.mounted) return;
      state = state.copyWith(snapshot: snapshot, loading: false, error: null);
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    }
  }
}
