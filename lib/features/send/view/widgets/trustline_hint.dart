// lib/features/send/view/widgets/trustline_hint.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:provider/provider.dart';

class TrustlineHint extends StatelessWidget {
  const TrustlineHint({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();

    if (vm.isXlm) return const SizedBox.shrink();
    if (vm.to.trim().isEmpty) return const SizedBox.shrink();

    // Checking state
    if (vm.checking) {
      return _HintContainer(
        gradient: [
          c.primary.withValues(alpha: 0.05),
          c.primary.withValues(alpha: 0.02),
        ],
        borderColor: c.primary.withValues(alpha: 0.08),
        child: Row(
          children: [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: c.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Checking USDC trustline\u2026',
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // No trustline
    if (vm.destHasUsdcTL == false) {
      return _HintContainer(
        gradient: [
          c.error.withValues(alpha: 0.06),
          c.error.withValues(alpha: 0.02),
        ],
        borderColor: c.error.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.alertTriangle,
                  size: 12, color: c.error.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This address has no USDC trustline.',
                style: TextStyle(
                  color: c.error.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Trustline verified
    if (vm.destHasUsdcTL == true) {
      return _HintContainer(
        gradient: [
          c.success.withValues(alpha: 0.06),
          c.success.withValues(alpha: 0.02),
        ],
        borderColor: c.success.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: c.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.checkCircle,
                  size: 12, color: c.success.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 10),
            Text(
              'USDC trustline verified',
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _HintContainer extends StatelessWidget {
  const _HintContainer({
    required this.gradient,
    required this.borderColor,
    required this.child,
  });

  final List<Color> gradient;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}