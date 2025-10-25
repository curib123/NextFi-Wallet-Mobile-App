import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border.withOpacity(.35)),
          gradient: c.primaryGradient,
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: [chip('10%', .10), chip('25%', .25), chip('50%', .50), chip('75%', .75), chip('100%', 1.0)],
      ),
    );
  }
}
