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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          AssetLogo(keyOrSymbol: token, size: 22),
          const SizedBox(width: 12),
          Text(
            'Balance',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            amt(balance),
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            token,
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}