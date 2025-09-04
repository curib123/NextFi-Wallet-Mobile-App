// lib/Screen/stake/widgets/stake_guide_sheet.dart
//
// ✅ Stake 2.0 only
// ✅ Scrollable with draggable bottom-sheet behavior
// ✅ Clean, modern UI consistent with your AppColor palette

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// What the user picked in the guide (only Stake 2.0 is supported here).
enum StakeGuideChoice { v2 }

/// Show the staking guide as a modern, scrollable modal bottom sheet (Stake 2.0 only).
Future<StakeGuideChoice?> showStakeGuideSheet(BuildContext context) {
  final colors = AppColor.of(context);
  return showModalBottomSheet<StakeGuideChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _StakeGuideV2Sheet(scrollController: scrollController),
      );
    },
  );
}

class _StakeGuideV2Sheet extends StatelessWidget {
  const _StakeGuideV2Sheet({super.key, required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    TextStyle hStyle([Color? color]) =>
        TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? c.textPrimary);
    final pStyle = TextStyle(fontSize: 14, color: c.textSecondary, height: 1.35);

    Widget bullet(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: c.textSecondary)),
        Expanded(child: Text(text, style: pStyle)),
      ],
    );

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Row(
            children: [
              Icon(LucideIcons.info, color: c.info),
              const SizedBox(width: 8),
              Text('Staking Guide (2.0)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const Spacer(),
              IconButton(
                icon: Icon(LucideIcons.x, color: c.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stake 2.0 Card (ONLY)
          _GuideCard(
            title: 'Stake 2.0 (Stake / Unstake / Withdraw)',
            titleColor: c.accent,
            children: [
              bullet('Stake any time. Unstake any time.'),
              bullet('After Unstake: wait ~14 days, then tap Withdraw to get TRX back.'),
              bullet('Up to 32 parallel unstakes; you can cancel pending unstakes.'),
              bullet('Supports delegating Energy/Bandwidth to other addresses.'),
              const SizedBox(height: 8),
              _HintChip(color: c.accent, icon: LucideIcons.timer, text: 'Flexible • withdraw step required'),
            ],
          ),

          const SizedBox(height: 10),

          // Quick guide Energy vs Bandwidth (optional but useful)
          _GuideCard(
            title: 'Which resource do I need?',
            titleColor: c.primary,
            children: [
              Text('ENERGY', style: hStyle(c.primary)),
              const SizedBox(height: 6),
              bullet('Used mainly by smart-contract (TRC-20) calls, e.g., USDT transfers.'),
              bullet('Stake for ENERGY to reduce contract fees.'),
              const SizedBox(height: 10),
              Text('BANDWIDTH', style: hStyle(c.primary)),
              const SizedBox(height: 6),
              bullet('Used for basic TRX transfers and simple transactions.'),
              bullet('Stake for BANDWIDTH to reduce TRX transfer fees.'),
            ],
          ),

          const SizedBox(height: 10),

          // Tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: c.successGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(LucideIcons.lightbulb, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keep a small TRX buffer for fees—if you run out of resources, TRX may still be burned.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Single action: Use Stake 2.0
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(LucideIcons.zap),
              label: const Text('Use Stake 2.0'),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, StakeGuideChoice.v2),
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.titleColor,
    required this.children,
  });

  final String title;
  final Color titleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: titleColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
