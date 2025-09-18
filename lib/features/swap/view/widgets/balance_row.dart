import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';

class BalanceRow extends StatelessWidget {
  final double xlm, usdc;
  final NumberFormat fmt;

  const BalanceRow({
    super.key,
    required this.xlm,
    required this.usdc,
    required NumberFormat numberFormat,
  }) : fmt = numberFormat;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    Widget chip(String assetKey, double value) {
      final text = value >= 100 ? NumberFormat('#,##0.00').format(value) : fmt.format(value);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.primary.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetLogo(keyOrSymbol: assetKey, size: 16),
            const SizedBox(width: 6),
            Text(
              '$assetKey: ',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5, letterSpacing: .2),
            ),
            Text(
              text,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: chip('XLM', xlm)),
        const SizedBox(width: 8),
        Expanded(child: chip('USDC', usdc)),
      ],
    );
  }
}
