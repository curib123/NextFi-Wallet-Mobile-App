import 'package:next_fi/services/merchant_payment_account/merchant_payment_account_core_service.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';

enum MerchantOnboardingStep { profile, paymentAccount, completed }

class MerchantOnboardingSnapshot {
  final MerchantOnboardingStep nextStep;
  final int nextStepIndex;
  final MerchantProfileModel? merchantProfile;
  final List<MerchantPaymentAccountModel> paymentAccounts;

  const MerchantOnboardingSnapshot({
    required this.nextStep,
    required this.nextStepIndex,
    this.merchantProfile,
    this.paymentAccounts = const [],
  });

  bool get isCompleted => nextStep == MerchantOnboardingStep.completed;

  /// Whether the user can take an action for the current step
  /// (false when profile is pending or suspended).
  bool get canProceed {
    if (isCompleted) return false;
    final p = merchantProfile;
    if (p == null) return true;
    if (p.isRejected) return true;
    if (p.isApproved && nextStep == MerchantOnboardingStep.paymentAccount) {
      return true;
    }
    return false; // pending or suspended
  }
}

class MerchantOnboardingFlowService {
  MerchantOnboardingFlowService._();
  static final MerchantOnboardingFlowService I =
      MerchantOnboardingFlowService._();

  Future<MerchantOnboardingSnapshot> getSnapshot() async {
    final profile = await MerchantProfileCoreService.I.getMe();

    List<MerchantPaymentAccountModel> paymentAccounts = const [];
    if (profile != null && profile.isApproved) {
      try {
        paymentAccounts =
            await MerchantPaymentAccountCoreService.I.listAll();
      } catch (_) {}
    }

    final step = _resolveStep(profile: profile, accounts: paymentAccounts);
    return MerchantOnboardingSnapshot(
      nextStep: step,
      nextStepIndex: _toIndex(step),
      merchantProfile: profile,
      paymentAccounts: paymentAccounts,
    );
  }

  MerchantOnboardingStep _resolveStep({
    required MerchantProfileModel? profile,
    required List<MerchantPaymentAccountModel> accounts,
  }) {
    if (profile == null || profile.isRejected) {
      return MerchantOnboardingStep.profile;
    }
    // Pending or suspended — still on profile step (waiting)
    if (profile.isPending || profile.isSuspended) {
      return MerchantOnboardingStep.profile;
    }
    if (profile.isApproved) {
      if (accounts.isEmpty) return MerchantOnboardingStep.paymentAccount;
      return MerchantOnboardingStep.completed;
    }
    return MerchantOnboardingStep.profile;
  }

  int _toIndex(MerchantOnboardingStep step) {
    switch (step) {
      case MerchantOnboardingStep.profile:
        return 1;
      case MerchantOnboardingStep.paymentAccount:
        return 2;
      case MerchantOnboardingStep.completed:
        return 3;
    }
  }
}
