import 'package:next_fi/core/services/merchant_profile/merchant_profile_core_service.dart';
import 'package:next_fi/core/services/merchant_profile/models/merchant_profile_models.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';

enum MerchantOnboardingStep { profile, paymentAccount, completed }

class MerchantOnboardingSnapshot {
  final MerchantOnboardingStep nextStep;
  final int nextStepIndex;
  final MerchantProfileModel? merchantProfile;
  final List<UserPaymentAccountModel> paymentAccounts;

  const MerchantOnboardingSnapshot({
    required this.nextStep,
    required this.nextStepIndex,
    this.merchantProfile,
    this.paymentAccounts = const [],
  });

  bool get isCompleted => nextStep == MerchantOnboardingStep.completed;

  bool get canProceed {
    if (isCompleted) return false;
    final p = merchantProfile;
    if (p == null) return true;
    if (p.isRejected) return true;
    if (p.isApproved && nextStep == MerchantOnboardingStep.paymentAccount) {
      return true;
    }
    return false;
  }
}

class MerchantOnboardingFlowService {
  MerchantOnboardingFlowService._();
  static final MerchantOnboardingFlowService I =
      MerchantOnboardingFlowService._();

  Future<MerchantOnboardingSnapshot> getSnapshot() async {
    final profile = await MerchantProfileCoreService.I.getMe();

    List<UserPaymentAccountModel> paymentAccounts = const [];
    if (profile != null && profile.isApproved) {
      try {
        paymentAccounts = await PaymentMethodAndAccountsCoreService.I
            .listMyPaymentAccounts(activeOnly: true);
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
    required List<UserPaymentAccountModel> accounts,
  }) {
    if (profile == null || profile.isRejected) {
      return MerchantOnboardingStep.profile;
    }
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
