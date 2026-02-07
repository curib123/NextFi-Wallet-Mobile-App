// lib/features/send/view/widgets/percent_chips_row.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class PercentChipsRow extends StatelessWidget {
  const PercentChipsRow({
    super.key,
    required this.onPick,
    this.activePct,
  });

  final void Function(double pct) onPick;
  final double? activePct;

  static const _presets = [
    ('10%', 0.10),
    ('25%', 0.25),
    ('50%', 0.50),
    ('75%', 0.75),
    ('MAX', 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        for (int i = 0; i < _presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _chip(c, _presets[i].$1, _presets[i].$2)),
        ],
      ],
    );
  }

  Widget _chip(AppColor c, String label, double pct) {
    final isActive =
        activePct != null && (activePct! - pct).abs() < 0.001;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPick(pct),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isActive
                ? c.primary.withValues(alpha: 0.1)
                : c.primary.withValues(alpha: 0.04),
            border: Border.all(
              color: isActive
                  ? c.primary.withValues(alpha: 0.4)
                  : c.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? c.primary : c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}