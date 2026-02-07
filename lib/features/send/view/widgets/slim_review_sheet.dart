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
  });

  final String tokenStr, sender, to, recipientGets;
  final String txFeeXlm, netFeeXlm, extraLabel, extraValue;
  final VoidCallback onCancel, onConfirm;

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
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          decoration: BoxDecoration(
            color: c.border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Review',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c.textPrimary)),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border:
                  Border.all(color: c.primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetLogo(keyOrSymbol: tokenStr, size: 14),
                    const SizedBox(width: 6),
                    Text(tokenStr,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Recipient receives (highlighted)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.arrowUpRight,
                    size: 16, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Recipient receives',
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 12)),
                ),
                Text(
                  '$recipientGets $tokenStr',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            children: [
              _detailCard(c, [
                _kvRow(c, 'From', sender, mono: true),
                Divider(height: 1, color: c.border.withValues(alpha: 0.1)),
                _kvRow(c, 'To', to, mono: true),
              ]),
              const SizedBox(height: 8),
              _detailCard(c, [
                _kvRow(c, 'Est. transaction fee', '$estCombinedStr XLM'),
                Divider(height: 1, color: c.border.withValues(alpha: 0.1)),
                _kvRow(c, extraLabel, extraValue),
              ]),
            ],
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: c.textSecondary,
                    side: BorderSide(
                        color: c.border.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(LucideIcons.check,
                      size: 16, color: Colors.white),
                  label: const Text('Confirm',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: c.primary,
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
        border: Border.all(color: c.border.withValues(alpha: 0.15)),
      ),
      child: Column(children: children),
    );
  }

  Widget _kvRow(AppColor c, String label, String value,
      {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontFamily: mono ? 'monospace' : null,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}