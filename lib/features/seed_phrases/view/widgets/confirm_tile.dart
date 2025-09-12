// lib/features/seed_phrase/view/widgets/confirm_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

class ConfirmTile extends StatelessWidget {
  const ConfirmTile({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final bgOn = accent.withOpacity(0.08);
    final borderOn = accent.withOpacity(0.9);

    return Semantics(
      button: true, toggled: value, label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? bgOn : colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? borderOn : colors.border.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 4, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: value ? [accent.withOpacity(.9), accent.withOpacity(.55)] : [Colors.transparent, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: value ? accent.withOpacity(.15) : colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: value ? borderOn : colors.border.withOpacity(.25)),
                ),
                child: Icon(icon, size: 18, color: value ? accent : colors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500, height: 1.2),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: value
                    ? Icon(LucideIcons.checkCircle, key: const ValueKey('on'), color: accent, size: 22)
                    : Icon(LucideIcons.circle, key: const ValueKey('off'), color: colors.border, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
