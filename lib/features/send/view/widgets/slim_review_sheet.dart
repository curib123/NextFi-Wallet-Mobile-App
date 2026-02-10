// lib/features/send/view/widgets/slim_review_sheet.dart
import 'package:flutter/material.dart';
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
      children: [
        // Drag handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(
            color: c.border.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text(
                'Review',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border:
                  Border.all(color: c.primary.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetLogo(keyOrSymbol: tokenStr, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tokenStr,
                      style: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Recipient receives — hero card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.primary.withValues(alpha: 0.07),
                  c.primary.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.arrowUpRight,
                      size: 14, color: c.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recipient receives',
                    style: TextStyle(
                      color: c.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '$recipientGets $tokenStr',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Detail rows
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            children: [
              _detailCard(c, [
                _kvRow(c, 'From', sender, mono: true),
                Divider(height: 1, color: c.border.withValues(alpha: 0.06)),
                _kvRow(c, 'To', to, mono: true),
              ]),
              const SizedBox(height: 10),
              _detailCard(c, [
                _kvRow(c, 'Est. fee', '$estCombinedStr XLM'),
                Divider(height: 1, color: c.border.withValues(alpha: 0.06)),
                _kvRow(c, extraLabel, extraValue),
                if (remainingExpendable != null) ...[
                  Divider(
                      height: 1,
                      color: c.border.withValues(alpha: 0.06)),
                  _kvRow(c, 'Remaining balance', remainingExpendable!,
                      muted: true),
                ],
              ]),
            ],
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: sending ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    foregroundColor: c.textSecondary,
                    side: BorderSide(
                        color: c.border.withValues(alpha: 0.25)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: FilledButton.icon(
                    onPressed: sending ? null : onConfirm,
                    icon: sending
                        ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    )
                        : const Icon(LucideIcons.check,
                        size: 15, color: Colors.white),
                    label: Text(
                      sending ? 'Sending\u2026' : 'Confirm',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: sending
                          ? c.primary.withValues(alpha: 0.6)
                          : c.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailCard(AppColor c, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }

  Widget _kvRow(AppColor c, String label, String value,
      {bool mono = false, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: muted
                  ? c.textSecondary.withValues(alpha: 0.5)
                  : c.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: TextStyle(
                color: muted
                    ? c.textSecondary.withValues(alpha: 0.6)
                    : c.textPrimary,
                fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
                fontFamily: mono ? 'monospace' : null,
                fontSize: 12.5,
                height: 1.25,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}