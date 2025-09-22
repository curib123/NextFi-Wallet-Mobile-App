import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class DirectionSwitcher extends StatelessWidget {
  final bool isXlmToUsdc;
  final VoidCallback onFlip;
  const DirectionSwitcher({super.key, required this.isXlmToUsdc, required this.onFlip});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    Widget seg(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: active ? c.primaryGradient : null,
              color: active ? null : c.surface,
              border: Border.all(color: c.border.withOpacity(.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? c.surface
            : c.primary.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(.35)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          seg('XLM → USDC', isXlmToUsdc, () { if (!isXlmToUsdc) onFlip(); }),
          const SizedBox(width: 6),
          seg('USDC → XLM', !isXlmToUsdc, () { if (isXlmToUsdc) onFlip(); }),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onFlip,
            icon: Icon(LucideIcons.arrowUpDown, color: c.primary),
            tooltip: 'Flip',
          ),
        ],
      ),
    );
  }
}
