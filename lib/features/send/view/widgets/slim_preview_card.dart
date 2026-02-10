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
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                LucideIcons.fileText,
                size: 16,
                color: c.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Summary',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssetLogo(keyOrSymbol: token, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    token,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recipient receives (highlighted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: c.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.arrowUpRight,
                  size: 15,
                  color: c.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Recipient receives',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${recipientGets.toStringAsFixed(6)} $token',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Network fee
          _DetailRow(
            c: c,
            icon: LucideIcons.coins,
            label: 'Network fee',
            value: '${estFee.toStringAsFixed(7)} XLM',
          ),

          if (isXLM && (totalDeductedXlm ?? 0) > 0) ...[
            const SizedBox(height: 8),
            _DetailRow(
              c: c,
              icon: LucideIcons.minusCircle,
              label: 'Total deducted',
              value: '${totalDeductedXlm!.toStringAsFixed(6)} XLM',
            ),
          ],

          if (!isXLM) ...[
            const SizedBox(height: 8),
            _DetailRow(
              c: c,
              icon: LucideIcons.wallet,
              label: 'XLM for fees',
              value: '${(xlmNeededForFees ?? 0).toStringAsFixed(7)} XLM',
            ),
          ],

          // Remaining balance
          if (remainingExpendable != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                color: c.border.withValues(alpha: 0.2),
                height: 1,
              ),
            ),
            _DetailRow(
              c: c,
              icon: LucideIcons.piggyBank,
              label: 'Remaining balance',
              value: '${remainingExpendable!.toStringAsFixed(isXLM ? 6 : 4)} $token',
              isMuted: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.isMuted = false,
  });

  final AppColor c;
  final IconData icon;
  final String label;
  final String value;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isMuted
                ? c.textSecondary.withValues(alpha: 0.4)
                : c.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: isMuted ? 0.5 : 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isMuted ? c.textSecondary : c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}