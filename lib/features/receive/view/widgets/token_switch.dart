// lib/features/receive/view/widgets/token_switch.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class TokenSwitch extends StatelessWidget {
  const TokenSwitch({
    super.key,
    required this.xlmSelected,
    required this.onSelectXLM,
    required this.onSelectUSDC,
  });

  final bool xlmSelected;
  final VoidCallback onSelectXLM;
  final VoidCallback onSelectUSDC;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(child: _SegmentButton(label: 'XLM', selected: xlmSelected, onTap: onSelectXLM, color: c)),
          const SizedBox(width: 8),
          Expanded(child: _SegmentButton(label: 'USDC', selected: !xlmSelected, onTap: onSelectUSDC, color: c)),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap, required this.color});
  final String label; final bool selected; final VoidCallback onTap; final AppColor color;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color.primary : Colors.transparent;
    final fg = selected ? color.onPrimary : color.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}
