// lib/features/send/view/widgets/balance_line.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';

class BalanceLine extends StatelessWidget {
  final String token;
  final double balance;

  const BalanceLine({super.key, required this.token, required this.balance});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    String amt(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primary.withValues(alpha: 0.06),
            c.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Asset icon with soft glow
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AssetLogo(keyOrSymbol: token, size: 20),
          ),
          const SizedBox(width: 12),

          // Label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spendable',
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                token,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Balance amount
          Text(
            amt(balance),
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            token,
            style: TextStyle(
              color: c.textSecondary.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}