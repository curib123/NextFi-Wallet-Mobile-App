import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/transactions/view/widgets/asset_logo.dart';

class BalanceLine extends StatelessWidget {
  final String token;
  final double balance;
  const BalanceLine({super.key, required this.token, required this.balance});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    String amt(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);
    return Row(children: [
      AssetLogo(asset: token, size: 16),
      const SizedBox(width: 8),
      Text('Balance: ', style: TextStyle(color: c.textSecondary)),
      Text('$token ${amt(balance)}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
    ]);
  }
}
