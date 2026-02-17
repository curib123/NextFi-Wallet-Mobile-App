import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/profile/models/profile_models.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';

import 'models/verification_models.dart';
import 'verification_core_service.dart';

enum VerificationStep {
  profile,
  paymentMethodSetup,
  selfieVerification,
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
    // Verification status is required for this screen.
    final verification = await _verification.getMe();

    // Profile/payment are best-effort so the screen still works even if
    // one dependency endpoint is temporarily unavailable.
    ProfileModel? profile;
    try {
      profile = await _profile.getMe();
    } catch (_) {
      profile = null;
    }

    List<UserPaymentAccountModel> paymentAccounts;
    try {
      paymentAccounts = await _payments.listMyPaymentAccounts(activeOnly: true);
    } catch (_) {
      paymentAccounts = const [];
    }

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

    bool hasText(String? v) => v != null && v.trim().isNotEmpty;
    final verificationUserId = verification.userId.trim();
    final hasActivePayment = paymentAccounts.any(
      (account) =>
          account.isActive &&
          hasText(account.id) &&
          hasText(account.userId) &&
          (!hasText(verificationUserId) ||
              account.userId.trim() == verificationUserId) &&
          hasText(account.paymentMethodId) &&
          hasText(account.accountName),
    );
    if (!hasActivePayment) return VerificationStep.paymentMethodSetup;

    // Step 3: selfie submission.
    final selfieDone = verification.hasSubmittedSelfie;
    if (!selfieDone) return VerificationStep.selfieVerification;

    // Server status is authoritative after all required local steps are met.
    if (verification.status == TrustStatus.reviewing ||
        verification.status == TrustStatus.ready ||
        verification.status == TrustStatus.suspended) {
      return VerificationStep.completed;
    }

    return VerificationStep.completed;
  }

  int _toStepIndex(VerificationStep step) {
    switch (step) {
      case VerificationStep.profile:
        return 1;
      case VerificationStep.paymentMethodSetup:
        return 2;
      case VerificationStep.selfieVerification:
        return 3;
      case VerificationStep.completed:
        return 4;
    }
  }
}
