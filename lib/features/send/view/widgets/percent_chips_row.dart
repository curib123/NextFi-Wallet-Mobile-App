// lib/features/send/view/widgets/percent_chips_row.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          Expanded(
            child: _Chip(
              c: c,
              label: _presets[i].$1,
              pct: _presets[i].$2,
              isActive: activePct != null &&
                  (activePct! - _presets[i].$2).abs() < 0.001,
              onTap: () => onPick(_presets[i].$2),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.c,
    required this.label,
    required this.pct,
    required this.isActive,
    required this.onTap,
  });

  final AppColor c;
  final String label;
  final double pct;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? c.primary.withValues(alpha: 0.12)
              : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? c.primary.withValues(alpha: 0.3)
                : c.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? c.primary : c.textSecondary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}