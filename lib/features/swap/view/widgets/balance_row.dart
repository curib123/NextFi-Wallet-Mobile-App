import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class BalanceRow extends StatelessWidget {
  final double xlm, usdc;
  final NumberFormat fmt;
  const BalanceRow({super.key, required this.xlm, required this.usdc, required NumberFormat numberFormat})
      : fmt = numberFormat;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    Widget pill(String label, double v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border.withOpacity(.35)),
      ),
      child: Text(
        '$label: ${v >= 100 ? NumberFormat('#,##0.00').format(v) : fmt.format(v)}',
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );

    return Row(children: [
      Expanded(child: pill('XLM', xlm)),
      const SizedBox(width: 8),
      Expanded(child: pill('USDC', usdc)),
    ]);
  }
}
