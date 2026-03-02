// lib/features/price_chart/view/widgets/token_tabs.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class TokenTabs extends StatelessWidget {
  const TokenTabs({super.key, required this.token, required this.onChanged});
  final String token; // 'XLM' or 'USDC'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    const items = ['XLM', 'USDC'];

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((t) {
          final selected = t == token;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => onChanged(t),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? c.primary.withValues(alpha: 0.14) : c.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.2,
                    color: selected ? c.primary : c.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
