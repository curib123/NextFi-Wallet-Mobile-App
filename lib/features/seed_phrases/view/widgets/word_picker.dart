import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class WordCountPicker extends StatelessWidget {
  final int current;           // 12 or 24
  final bool loading;          // disable while loading
  final ValueChanged<int> onPick;

  const WordCountPicker({
    super.key,
    required this.current,
    required this.loading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final is12 = current == 12;
    final is24 = current == 24;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountChip(
          label: '12 words',
          selected: is12,
          onTap: loading ? null : () => onPick(12),
        ),
        const SizedBox(width: 10),
        _CountChip(
          label: '24 words',
          selected: is24,
          onTap: loading ? null : () => onPick(24),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _CountChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withOpacity(.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? colors.primary : colors.border.withOpacity(.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(LucideIcons.check, size: 14, color: colors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.primary : colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
