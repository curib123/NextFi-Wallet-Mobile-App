import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

class DirectionSwitcher extends StatelessWidget {
  final bool isXlmToUsdc;
  final VoidCallback onFlip;
  const DirectionSwitcher({super.key, required this.isXlmToUsdc, required this.onFlip});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(children: [
        Expanded(child: _SegBtn(active: isXlmToUsdc, label: 'XLM → USDC', onTap: () { if (!isXlmToUsdc) onFlip(); })),
        const SizedBox(width: 6),
        Expanded(child: _SegBtn(active: !isXlmToUsdc, label: 'USDC → XLM', onTap: () { if (isXlmToUsdc) onFlip(); })),
        const SizedBox(width: 6),
        IconButton(visualDensity: VisualDensity.compact, onPressed: onFlip, icon: Icon(LucideIcons.arrowUpDown, color: c.primary), tooltip: 'Flip'),
      ]),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _SegBtn({required this.active, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? c.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: active ? Colors.white : c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ),
    );
  }
}
