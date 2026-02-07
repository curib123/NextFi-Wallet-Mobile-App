// lib/features/send/view/widgets/slim_preview_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';

class SlimPreviewCard extends StatelessWidget {
  final bool isXLM;
  final String token;
  final double recipientGets;
  final double estNetworkFeeXlm;
  final double txFeeXlm;
  final double? totalBudgetXlm;
  final double? needsXlmForFeesIfUsdc;

  const SlimPreviewCard({
    super.key,
    required this.isXLM,
    required this.token,
    required this.recipientGets,
    required this.estNetworkFeeXlm,
    required this.txFeeXlm,
    required this.totalBudgetXlm,
    required this.needsXlmForFeesIfUsdc,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final double estTxFeeCombined = txFeeXlm + estNetworkFeeXlm;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(LucideIcons.userCheck,
                  size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('Preview',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              AssetLogo(keyOrSymbol: token, size: 14),
              const SizedBox(width: 5),
              Text(token,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: c.border.withValues(alpha: 0.15)),
          const SizedBox(height: 10),

          _row(c, 'Recipient receives',
              '${recipientGets.toStringAsFixed(6)} $token'),
          const SizedBox(height: 6),
          _row(c, 'Est. transaction fee',
              '${estTxFeeCombined.toStringAsFixed(7)} XLM'),

          if (isXLM && (totalBudgetXlm ?? 0) > 0) ...[
            const SizedBox(height: 6),
            _row(c, 'Total deducted',
                '${totalBudgetXlm!.toStringAsFixed(6)} XLM'),
          ],
          if (!isXLM) ...[
            const SizedBox(height: 6),
            _row(c, 'XLM required for fees',
                '${(needsXlmForFeesIfUsdc ?? 0).toStringAsFixed(7)} XLM'),
          ],
        ],
      ),
    );
  }

  Widget _row(AppColor c, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ),
        const SizedBox(width: 6),
        Text(value,
            style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ],
    );
  }
}