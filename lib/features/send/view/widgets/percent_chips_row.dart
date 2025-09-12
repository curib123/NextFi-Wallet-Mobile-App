import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class PercentChipsRow extends StatelessWidget {
  const PercentChipsRow({super.key, required this.onPick});
  final void Function(double pct) onPick;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    Widget chip(String label, double pct) => InkWell(
      onTap: () => onPick(pct),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.primary.withOpacity(0.18))),
        child: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        chip('10%', 0.10), chip('25%', 0.25), chip('50%', 0.50), chip('75%', 0.75), chip('100%', 1.00),
      ]),
    );
  }
}
