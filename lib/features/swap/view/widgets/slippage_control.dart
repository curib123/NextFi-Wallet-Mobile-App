import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class SlippageControl extends StatelessWidget {
  final double value, min, max;
  final String label;
  final ValueChanged<double> onChanged;
  final String Function(double) fmt;
  const SlippageControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: c.textSecondary)),
            const Spacer(),
            Row(
              children: [
                const Icon(LucideIcons.percent, size: 14),
                const SizedBox(width: 4),
                Text('${fmt(value)}%', style: TextStyle(color: c.textPrimary, fontSize: 12)),
              ],
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 45,
            label: '${fmt(value)}%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
