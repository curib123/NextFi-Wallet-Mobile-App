import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_state.dart';

class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.pct, required this.up});
  final double pct;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final clr = up ? c.primary : c.error;
    final bg = clr.withValues(alpha: 0.12);
    final icon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: clr.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: clr),
          const SizedBox(width: 6),
          Text(
            fmtPct(pct),
            style: TextStyle(
              color: clr,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
