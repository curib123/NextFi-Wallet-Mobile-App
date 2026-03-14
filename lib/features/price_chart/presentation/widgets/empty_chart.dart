// lib/features/price_chart/view/widgets/empty_chart.dart
import 'package:flutter/material.dart';

class EmptyChart extends StatelessWidget {
  const EmptyChart({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        'No data',
        style: TextStyle(color: c.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
      ),
    );
  }
}
