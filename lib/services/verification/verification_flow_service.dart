import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';

import 'models/verification_models.dart';
import 'verification_core_service.dart';

enum VerificationStep {
  profile,
  selfieVerification,
  paymentMethodSetup,
  completed,
}

class VerificationFlowSnapshot {
  final VerificationStep nextStep;
  final int nextStepIndex;
  final ProfileModel? profile;
  final VerificationModel verification;
  final List<UserPaymentAccountModel> paymentAccounts;

  const VerificationFlowSnapshot({
    required this.nextStep,
    required this.nextStepIndex,
    required this.profile,
    required this.verification,
    required this.paymentAccounts,
  });

  bool get isCompleted => nextStep == VerificationStep.completed;
}

class VerificationFlowService {
  VerificationFlowService._();

  static final VerificationFlowService I = VerificationFlowService._();

  final ProfileCoreService _profile = ProfileCoreService.I;
  final VerificationCoreService _verification = VerificationCoreService.I;
  final PaymentMethodAndAccountsCoreService _payments =
      PaymentMethodAndAccountsCoreService.I;

  Future<VerificationFlowSnapshot> getSnapshot() async {
    final profile = await _profile.getMe();
    final verification = await _verification.getMe();
    final paymentAccounts = await _payments.listMyPaymentAccounts(activeOnly: true);

    final nextStep = _resolveStep(
      profile: profile,
      verification: verification,
      paymentAccounts: paymentAccounts,
    );

    return VerificationFlowSnapshot(
      nextStep: nextStep,
      nextStepIndex: _toStepIndex(nextStep),
      profile: profile,
      verification: verification,
      paymentAccounts: paymentAccounts,
    );
  }

  VerificationStep _resolveStep({
    required ProfileModel? profile,
    required VerificationModel verification,
    required List<UserPaymentAccountModel> paymentAccounts,
  }) {
    final profileDone = profile?.isVerificationIdentityComplete == true;
    if (!profileDone) return VerificationStep.profile;

    final selfieDone = verification.hasSubmittedSelfie || verification.isFinalReviewState;
    if (!selfieDone) return VerificationStep.selfieVerification;

    final hasActivePayment = paymentAccounts.any((account) => account.isActive);
    if (!hasActivePayment) return VerificationStep.paymentMethodSetup;

    return VerificationStep.completed;
  }

  int _toStepIndex(VerificationStep step) {
    switch (step) {
      case VerificationStep.profile:
        return 1;
      case VerificationStep.selfieVerification:
        return 2;
      case VerificationStep.paymentMethodSetup:
        return 3;
      case VerificationStep.completed:
        return 4;
    }
  }
}
