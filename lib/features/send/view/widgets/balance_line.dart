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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          AssetLogo(keyOrSymbol: token, size: 20),
          const SizedBox(width: 10),
          Text('Available',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            '${amt(balance)} $token',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}