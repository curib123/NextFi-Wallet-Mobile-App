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
    return Row(
      children: [
        Expanded(child: _SegmentButton(label: 'XLM', selected: xlmSelected, onTap: onSelectXLM, color: c)),
        const SizedBox(width: 8),
        Expanded(child: _SegmentButton(label: 'USDC', selected: !xlmSelected, onTap: onSelectUSDC, color: c)),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap, required this.color});
  final String label; final bool selected; final VoidCallback onTap; final AppColor color;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color.primary : color.primary.withOpacity(0.06);
    final fg = selected ? Colors.white : color.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.primary.withOpacity(selected ? 0.0 : 0.15)),
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
