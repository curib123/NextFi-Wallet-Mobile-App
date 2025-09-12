// lib/features/price_chart/view/widgets/range_tabs.dart
import 'package:flutter/material.dart';
import '../../../price_chart/model/price_chart_state.dart';
import 'segment_button.dart';

class RangeTabs extends StatelessWidget {
  const RangeTabs({super.key, required this.range, required this.onChanged});
  final PriceChartRange range;
  final ValueChanged<PriceChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const items = [
      (PriceChartRange.h24, '24H'),
      (PriceChartRange.w1,  '1W'),
      (PriceChartRange.m1,  '1M'),
      (PriceChartRange.y1,  '1Y'),
      (PriceChartRange.all, 'ALL'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((e) {
          final selected = e.$1 == range;
          return Expanded(
            child: SegmentButton(
              label: e.$2,
              selected: selected,
              onTap: () => onChanged(e.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}
