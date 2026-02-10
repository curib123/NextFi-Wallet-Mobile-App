// lib/features/send/view/widgets/slim_review_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';

class SlimReviewSheet extends StatelessWidget {
  const SlimReviewSheet({
    super.key,
    required this.tokenStr,
    required this.sender,
    required this.to,
    required this.recipientGets,
    required this.txFeeXlm,
    required this.netFeeXlm,
    required this.extraLabel,
    required this.extraValue,
    required this.onCancel,
    required this.onConfirm,
    this.remainingExpendable,
    this.sending = false,
  });

  final String tokenStr, sender, to, recipientGets;
  final String txFeeXlm, netFeeXlm, extraLabel, extraValue;
  final VoidCallback onCancel, onConfirm;
  final String? remainingExpendable;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final double tx = double.tryParse(txFeeXlm) ?? 0.0;
    final double net = double.tryParse(netFeeXlm) ?? 0.0;
    final String estCombinedStr = (tx + net).toStringAsFixed(7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: c.border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                LucideIcons.fileCheck,
                size: 20,
                color: c.textPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                'Review Transaction',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssetLogo(keyOrSymbol: tokenStr, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    tokenStr,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Amount card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.arrowUpRight,
                      size: 16,
                      color: c.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recipient receives',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      recipientGets,
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tokenStr,
                      style: TextStyle(
                        color: c.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Detail cards
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            children: [
              _DetailCard(
                c: c,
                children: [
                  _DetailRow(
                    c: c,
                    icon: LucideIcons.userCircle,
                    label: 'From',
                    value: sender,
                    mono: true,
                  ),
                  Divider(
                    height: 20,
                    color: c.border.withValues(alpha: 0.2),
                  ),
                  _DetailRow(
                    c: c,
                    icon: LucideIcons.target,
                    label: 'To',
                    value: to,
                    mono: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailCard(
                c: c,
                children: [
                  _DetailRow(
                    c: c,
                    icon: LucideIcons.coins,
                    label: 'Network fee',
                    value: '$estCombinedStr XLM',
                  ),
                  Divider(
                    height: 20,
                    color: c.border.withValues(alpha: 0.2),
                  ),
                  _DetailRow(
                    c: c,
                    icon: LucideIcons.info,
                    label: extraLabel,
                    value: extraValue,
                  ),
                  if (remainingExpendable != null) ...[
                    Divider(
                      height: 20,
                      color: c.border.withValues(alpha: 0.2),
                    ),
                    _DetailRow(
                      c: c,
                      icon: LucideIcons.piggyBank,
                      label: 'Remaining balance',
                      value: remainingExpendable!,
                      muted: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: sending ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: c.border.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    foregroundColor: c.textSecondary,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () {
                    HapticFeedback.mediumImpact();
                    onConfirm();
                  },
                  icon: sending
                      ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  )
                      : const Icon(
                    LucideIcons.checkCircle,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    sending ? 'Sending…' : 'Confirm Send',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor:
                    sending ? c.primary.withValues(alpha: 0.7) : c.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.c,
    required this.children,
  });

  final AppColor c;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.muted = false,
  });

  final AppColor c;
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: muted
              ? c.textSecondary.withValues(alpha: 0.5)
              : c.textSecondary.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: muted ? 0.5 : 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                maxLines: 2,
                style: TextStyle(
                  color: muted ? c.textSecondary : c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? 'monospace' : null,
                  fontSize: mono ? 11.5 : 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}