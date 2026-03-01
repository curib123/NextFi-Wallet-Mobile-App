import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/features/merchant_flow/view/merchant_profile_setup_screen.dart';
import 'package:next_fi/features/verification_flow/view/payment_method_setup_screen.dart';
import 'package:next_fi/services/merchant_profile/merchant_onboarding_flow_service.dart';
import 'package:next_fi/services/merchant_profile/models/merchant_profile_models.dart';

class MerchantOnboardingFlowScreen extends StatefulWidget {
  const MerchantOnboardingFlowScreen({super.key});

  @override
  State<MerchantOnboardingFlowScreen> createState() =>
      _MerchantOnboardingFlowScreenState();
}

class _MerchantOnboardingFlowScreenState extends State<MerchantOnboardingFlowScreen>
    with SingleTickerProviderStateMixin {
  MerchantOnboardingSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await MerchantOnboardingFlowService.I.getSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Merchant Request',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _buildBody(c),
    );
  }

  Widget _buildBody(AppColor c) {
    if (_loading) {
      return const PageLoader(label: 'Checking merchant setup...');
    }
    if (_error != null) return _ErrorState(c: c, error: _error!, onRetry: _load);

    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final status = snapshot.merchantProfile?.status ?? MerchantStatus.unknown;
    final canContinue = snapshot.canProceed && !snapshot.isCompleted;

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.primary,
        backgroundColor: c.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            _HeroCard(c: c, snapshot: snapshot),
            const SizedBox(height: 12),
            _StatusNotice(c: c, status: status, snapshot: snapshot),
            const SizedBox(height: 20),
            Text(
              'STEPS',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            _StepTile(
              c: c,
              title: 'Merchant Profile',
              subtitle: 'Submit merchant profile request for review',
              icon: Icons.storefront_outlined,
              isDone: snapshot.nextStepIndex > 1,
              isCurrent: snapshot.nextStepIndex == 1,
              isLast: false,
            ),
            _StepTile(
              c: c,
              title: 'Merchant Payment Account',
              subtitle: 'Set up payment details after approval',
              icon: Icons.account_balance_wallet_outlined,
              isDone: snapshot.nextStepIndex > 2,
              isCurrent: snapshot.nextStepIndex == 2,
              isLast: true,
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: AppElevatedButton(
                onPressed: canContinue ? _continueFlow : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canContinue ? c.primary : c.border.withValues(alpha: 0.15),
                  foregroundColor: canContinue ? c.onPrimary : c.textSecondary,
                  disabledBackgroundColor: c.border.withValues(alpha: 0.12),
                  disabledForegroundColor: c.textSecondary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _ctaLabel(snapshot),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabel(MerchantOnboardingSnapshot snapshot) {
    if (snapshot.isCompleted) return 'Merchant Setup Completed';
    final profile = snapshot.merchantProfile;
    if (profile == null || profile.isRejected) {
      return snapshot.nextStepIndex == 1
          ? 'Start Merchant Profile Setup'
          : 'Continue';
    }
    if (profile.isPending) return 'Waiting for Approval';
    if (profile.isSuspended) return 'Application Suspended';
    if (profile.isApproved && snapshot.nextStepIndex == 2) {
      return 'Continue to Payment Account';
    }
    return 'Continue';
  }

  Future<void> _continueFlow() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    if (snapshot.nextStep == MerchantOnboardingStep.profile) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MerchantProfileSetupScreen(
            initial: snapshot.merchantProfile,
          ),
        ),
      );
      if (changed == true && mounted) await _load();
      return;
    }

    if (snapshot.nextStep == MerchantOnboardingStep.paymentAccount) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PaymentAccountSetupScreen(isMerchant: true),
        ),
      );
      if (changed == true && mounted) await _load();
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.c, required this.snapshot});

  final AppColor c;
  final MerchantOnboardingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.merchantProfile?.status ?? MerchantStatus.unknown;
    final accent = _accent(status);
    final step = snapshot.nextStepIndex.clamp(1, 3);
    final progress = snapshot.isCompleted ? 1.0 : (step - 1) / 2.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _label(status),
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.isCompleted ? 'Merchant onboarding complete' : 'Step $step of 2',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.isCompleted
                ? 'Your merchant profile and payment account are ready.'
                : 'Complete profile setup first. Payment account unlocks after approval.',
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: c.border.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Color _accent(MerchantStatus status) {
    switch (status) {
      case MerchantStatus.approved:
        return c.success;
      case MerchantStatus.pending:
        return c.warning;
      case MerchantStatus.rejected:
      case MerchantStatus.suspended:
        return c.error;
      case MerchantStatus.unknown:
        return c.primary;
    }
  }

  String _label(MerchantStatus status) {
    switch (status) {
      case MerchantStatus.pending:
        return 'PENDING';
      case MerchantStatus.approved:
        return 'APPROVED';
      case MerchantStatus.rejected:
        return 'REJECTED';
      case MerchantStatus.suspended:
        return 'SUSPENDED';
      case MerchantStatus.unknown:
        return 'NOT REQUESTED';
    }
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.c,
    required this.status,
    required this.snapshot,
  });

  final AppColor c;
  final MerchantStatus status;
  final MerchantOnboardingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String title;
    String body;
    Color accent;
    switch (status) {
      case MerchantStatus.pending:
        icon = Icons.hourglass_top_rounded;
        title = 'Profile Under Review';
        body =
            'Your profile request is pending approval. Payment setup unlocks after approval.';
        accent = c.warning;
        break;
      case MerchantStatus.approved:
        icon = Icons.verified_rounded;
        title = 'Profile Approved';
        body = snapshot.isCompleted
            ? 'Merchant setup is complete.'
            : 'Great! Continue to merchant payment account setup.';
        accent = c.success;
        break;
      case MerchantStatus.rejected:
        icon = Icons.restart_alt_rounded;
        title = 'Request Rejected';
        body = snapshot.merchantProfile?.rejectionReason?.trim().isNotEmpty == true
            ? snapshot.merchantProfile!.rejectionReason!
            : 'You can update details and submit a new merchant request.';
        accent = c.error;
        break;
      case MerchantStatus.suspended:
        icon = Icons.block_rounded;
        title = 'Request Suspended';
        body = snapshot.merchantProfile?.suspendReason?.trim().isNotEmpty == true
            ? snapshot.merchantProfile!.suspendReason!
            : 'Your merchant request is suspended. Please contact support.';
        accent = c.error;
        break;
      case MerchantStatus.unknown:
        icon = Icons.info_outline_rounded;
        title = 'Start Merchant Onboarding';
        body = 'Submit your merchant profile request first, then wait for approval.';
        accent = c.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final AppColor c;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDone
        ? c.success
        : isCurrent
            ? c.primary
            : c.textSecondary.withValues(alpha: 0.12);
    final fgColor = (isDone || isCurrent) ? c.onPrimary : c.textSecondary;
    final lineColor = (isDone ? c.success : c.textSecondary).withValues(alpha: 0.25);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: isDone
                      ? Icon(Icons.check_rounded, color: c.onPrimary, size: 16)
                      : Icon(icon, color: fgColor, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrent ? c.primary.withValues(alpha: 0.04) : c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? c.primary.withValues(alpha: 0.22)
                        : c.border.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.c,
    required this.error,
    required this.onRetry,
  });

  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: c.error, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t Load Merchant Flow',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppFilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

