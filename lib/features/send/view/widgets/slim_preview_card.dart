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
  final double? totalDeductedXlm;
  final double? xlmNeededForFees;
  final double? remainingExpendable;

  const SlimPreviewCard({
    super.key,
    required this.isXLM,
    required this.token,
    required this.recipientGets,
    required this.estNetworkFeeXlm,
    required this.txFeeXlm,
    this.totalDeductedXlm,
    this.xlmNeededForFees,
    this.remainingExpendable,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final double estFee = txFeeXlm + estNetworkFeeXlm;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.surface,
            c.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(LucideIcons.receipt,
                    size: 12, color: c.primary.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 8),
              Text(
                'Preview',
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetLogo(keyOrSymbol: token, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      token,
                      style: TextStyle(
                        color: c.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
                height: 1, color: c.border.withValues(alpha: 0.08)),
          ),

          // Rows
          _row(c, 'Recipient receives',
              '${recipientGets.toStringAsFixed(6)} $token'),
          const SizedBox(height: 8),
          _row(c, 'Est. fee', '${estFee.toStringAsFixed(7)} XLM'),

          if (isXLM && (totalDeductedXlm ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _row(c, 'Total deducted',
                '${totalDeductedXlm!.toStringAsFixed(6)} XLM',
                bold: true),
          ],

          if (!isXLM) ...[
            const SizedBox(height: 8),
            _row(c, 'XLM for fees',
                '${(xlmNeededForFees ?? 0).toStringAsFixed(7)} XLM'),
          ],

          // Remaining balance
          if (remainingExpendable != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                  height: 1, color: c.border.withValues(alpha: 0.06)),
            ),
            _row(
              c,
              'Remaining',
              '${remainingExpendable!.toStringAsFixed(isXLM ? 6 : 4)} $token',
              muted: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(AppColor c, String label, String value,
      {bool bold = false, bool muted = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted
                  ? c.textSecondary.withValues(alpha: 0.5)
                  : c.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: muted
                ? c.textSecondary.withValues(alpha: 0.6)
                : c.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}