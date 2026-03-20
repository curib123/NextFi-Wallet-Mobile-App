import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/modal/profile_setup_modal.dart';
import 'package:next_fi/core/widgets/modal/verification_consent_modal.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/payment_method_setup_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/selfie_verification_step_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/viewmodels/verification_flow_controller.dart';
import 'package:next_fi/core/services/secure_storage/security_storage.dart';
import 'package:next_fi/core/services/verification/verification_flow_service.dart';
import 'package:next_fi/core/services/verification/models/verification_models.dart';

class VerificationFlowScreen extends ConsumerStatefulWidget {
  const VerificationFlowScreen({
    super.key,
    this.onOpenProfileStep,
    this.onOpenSelfieStep,
    this.onOpenPaymentStep,
  });

  final Future<void> Function(BuildContext context)? onOpenProfileStep;
  final Future<void> Function(BuildContext context)? onOpenSelfieStep;
  final Future<void> Function(BuildContext context)? onOpenPaymentStep;

  @override
  ConsumerState<VerificationFlowScreen> createState() =>
      _VerificationFlowScreenState();
}

class _VerificationFlowScreenState extends ConsumerState<VerificationFlowScreen>
    with TickerProviderStateMixin {
  static const String _kVerificationConsentKey = 'verification.user_consent.v1';
  static const String _kVerificationConsentAtKey =
      'verification.user_consent_at.v1';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await ref.read(verificationFlowControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(verificationFlowControllerProvider, (previous, next) {
      final snapshotChanged = previous?.snapshot != next.snapshot;
      if (snapshotChanged && !next.loading && next.error == null) {
        _fadeController.forward(from: 0);
      }
    });
    final c = AppColor.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: _buildBody(c),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        'Verification',
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: c.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  Widget _buildBody(AppColor c) {
    final state = ref.watch(verificationFlowControllerProvider);
    if (state.loading) {
      return const PageLoader(label: 'Checking verification status...');
    }
    if (state.error != null) return _buildErrorState(c, state.error!);

    final snapshot = state.snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final status = snapshot.verification.status;
    final canContinue =
        status == TrustStatus.basic || status == TrustStatus.unknown;
    final isVerified = status == TrustStatus.ready;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.primary,
        backgroundColor: c.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            _StatusHeroCard(c: c, snapshot: snapshot),
            const SizedBox(height: 10),

            if (status == TrustStatus.reviewing)
              _NoticeBanner(
                c: c,
                icon: Icons.hourglass_top_rounded,
                title: 'Under Review',
                body:
                    'Your verification is being processed. We\'ll notify you when it\'s ready.',
                accent: c.warning,
              ),
            if (isVerified)
              _NoticeBanner(
                c: c,
                icon: Icons.verified_rounded,
                title: 'Account Verified',
                body:
                    'All steps are complete. You can now access verified features.',
                accent: c.success,
              ),
            if (status == TrustStatus.suspended)
              _NoticeBanner(
                c: c,
                icon: Icons.block_rounded,
                title: 'Verification Suspended',
                body:
                    snapshot.verification.suspendReason?.trim().isNotEmpty ==
                        true
                    ? snapshot.verification.suspendReason!
                    : 'Your verification was suspended. Please contact support.',
                accent: c.error,
              ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text(
                'STEPS',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            _StepList(
              c: c,
              nextStepIndex: snapshot.nextStepIndex,
              steps: const [
                (
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Fill in your identity details',
                ),
                (
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Payment Method',
                  subtitle: 'Set up your payment account',
                ),
                (
                  icon: Icons.camera_alt_outlined,
                  title: 'Identity Verification',
                  subtitle:
                      'Identity details, phone number, selfie & government ID',
                ),
              ],
            ),

            const SizedBox(height: 28),

            _CtaButton(
              c: c,
              snapshot: snapshot,
              canContinue: canContinue,
              onPressed: () => _continueFromSnapshot(snapshot),
            ),

            if (isVerified) ...[
              const SizedBox(height: 10),
              _AddPaymentButton(c: c, onPressed: _openPaymentSetup),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AppColor c, String error) {
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
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t Load Status',
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
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaymentSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaymentAccountSetupScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _continueFromSnapshot(VerificationFlowSnapshot snapshot) async {
    final consentGranted = await _ensureVerificationConsent(snapshot);
    if (!consentGranted) return;

    final step = snapshot.nextStepIndex > 3 ? 3 : snapshot.nextStepIndex;
    final handler = switch (step) {
      1 => widget.onOpenProfileStep,
      2 => widget.onOpenPaymentStep,
      3 => widget.onOpenSelfieStep,
      _ => widget.onOpenProfileStep,
    };

    if (handler != null) {
      if (!mounted) return;
      await handler(context);
      if (mounted) await _load();
      return;
    }

    if (!mounted) return;

    if (step == 2) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaymentAccountSetupScreen()),
      );
      if (mounted) await _load();
      return;
    }

    if (step == 3) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SelfieVerificationStepScreen()),
      );
      if (mounted) await _load();
      return;
    }

    await showProfileSetupModal(context, initial: snapshot.profile);
    if (mounted) await _load();
  }

  Future<bool> _ensureVerificationConsent(
    VerificationFlowSnapshot snapshot,
  ) async {
    final status = snapshot.verification.status;
    final needsConsent =
        (status == TrustStatus.basic || status == TrustStatus.unknown) &&
        !snapshot.isCompleted;
    if (!needsConsent) return true;

    try {
      final stored = await SecurityStorage.read(_kVerificationConsentKey);
      if (stored == 'accepted') return true;
    } catch (_) {}

    if (!mounted) return false;
    final accepted = await showVerificationConsentModal(context);
    if (accepted != true) return false;

    try {
      await SecurityStorage.save(_kVerificationConsentKey, 'accepted');
      await SecurityStorage.save(
        _kVerificationConsentAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
    return true;
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.c, required this.snapshot});

  final AppColor c;
  final VerificationFlowSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.verification.status;
    final accent = _accentColor(status);
    final label = _statusLabel(status);
    final progress = _computeProgress(snapshot);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
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
            snapshot.isCompleted
                ? 'All steps completed'
                : 'Step ${snapshot.nextStepIndex} of 3',
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
                ? 'Your verification is complete.'
                : 'Complete the remaining steps to get verified.',
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

  double _computeProgress(VerificationFlowSnapshot snapshot) {
    if (snapshot.isCompleted) return 1.0;
    final step = snapshot.nextStepIndex.clamp(1, 4);
    return (step - 1) / 3.0;
  }

  Color _accentColor(TrustStatus status) {
    switch (status) {
      case TrustStatus.ready:
        return c.success;
      case TrustStatus.reviewing:
        return c.warning;
      case TrustStatus.suspended:
        return c.error;
      case TrustStatus.basic:
      case TrustStatus.unknown:
        return c.primary;
    }
  }

  String _statusLabel(TrustStatus status) {
    switch (status) {
      case TrustStatus.basic:
        return 'BASIC';
      case TrustStatus.reviewing:
        return 'REVIEWING';
      case TrustStatus.ready:
        return 'VERIFIED';
      case TrustStatus.suspended:
        return 'SUSPENDED';
      case TrustStatus.unknown:
        return 'PENDING';
    }
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.c,
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final AppColor c;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
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

class _StepList extends StatelessWidget {
  const _StepList({
    required this.c,
    required this.nextStepIndex,
    required this.steps,
  });

  final AppColor c;
  final int nextStepIndex;
  final List<({IconData icon, String title, String subtitle})> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final index = i + 1;
        final isDone = nextStepIndex > index;
        final isCurrent = nextStepIndex == index;
        final isLast = index == steps.length;
        return _StepRow(
          c: c,
          index: index,
          icon: steps[i].icon,
          title: steps[i].title,
          subtitle: steps[i].subtitle,
          isDone: isDone,
          isCurrent: isCurrent,
          isLast: isLast,
        );
      }),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.c,
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final AppColor c;
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = isDone
        ? c.success
        : isCurrent
        ? c.primary
        : c.textSecondary.withValues(alpha: 0.3);

    final bgColor = isDone
        ? c.success
        : isCurrent
        ? c.primary
        : c.textSecondary.withValues(alpha: 0.12);

    final fgColor = (isDone || isCurrent)
        ? c.onPrimary
        : c.textSecondary.withValues(alpha: 0.5);

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
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: c.primary.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : isDone
                        ? [
                            BoxShadow(
                              color: c.success.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
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
                          color: dotColor.withValues(alpha: 0.25),
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
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? c.primary.withValues(alpha: 0.04)
                      : c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? c.primary.withValues(alpha: 0.22)
                        : c.border.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    _StatusChip(c: c, isDone: isDone, isCurrent: isCurrent),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.c,
    required this.isDone,
    required this.isCurrent,
  });

  final AppColor c;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Done',
          style: TextStyle(
            color: c.success,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Now',
          style: TextStyle(
            color: c.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Pending',
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.c,
    required this.snapshot,
    required this.canContinue,
    required this.onPressed,
  });

  final AppColor c;
  final VerificationFlowSnapshot snapshot;
  final bool canContinue;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _label();
    final isActive = canContinue && !snapshot.isCompleted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: AppElevatedButton(
        onPressed: isActive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? c.primary
              : c.border.withValues(alpha: 0.15),
          foregroundColor: isActive ? c.onPrimary : c.textSecondary,
          disabledBackgroundColor: c.border.withValues(alpha: 0.12),
          disabledForegroundColor: c.textSecondary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ],
        ),
      ),
    );
  }

  String _label() {
    switch (snapshot.verification.status) {
      case TrustStatus.reviewing:
        return 'Under Review';
      case TrustStatus.ready:
        return 'Account Verified';
      case TrustStatus.suspended:
        return 'Verification Suspended';
      case TrustStatus.basic:
      case TrustStatus.unknown:
        return snapshot.isCompleted
            ? 'All Steps Completed'
            : 'Continue Step ${snapshot.nextStepIndex}';
    }
  }
}

class _AddPaymentButton extends StatelessWidget {
  const _AddPaymentButton({required this.c, required this.onPressed});

  final AppColor c;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: AppOutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border.withValues(alpha: 0.35), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_card_rounded,
              size: 17,
              color: c.textPrimary.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Text(
              'Add Payment Account',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
