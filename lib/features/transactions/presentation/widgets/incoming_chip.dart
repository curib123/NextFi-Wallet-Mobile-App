import 'dart:async';
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

class IncomingChipData {
  IncomingChipData({
    required this.text,
    required this.color,
    required this.icon,
  }) : id = UniqueKey().toString();

  final String id;
  final String text;
  final Color color;
  final IconData icon;
  Timer? timer;
}

class IncomingChipBadge extends StatelessWidget {
  const IncomingChipBadge({
    super.key,
    required this.chip,
    required this.surface,
  });

  final IncomingChipData chip;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chip.color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColor.of(context).textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: chip.color),
          const SizedBox(width: 8),
          Text(
            chip.text,
            style: TextStyle(
              color: chip.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

