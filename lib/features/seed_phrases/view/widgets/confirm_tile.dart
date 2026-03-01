// lib/features/seed_phrase/view/widgets/confirm_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Clean confirmation checkbox tile
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

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? accent.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? accent.withValues(alpha: 0.2)
                : colors.border.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? accent : colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? accent : colors.border.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: value
                  ? Icon(
                LucideIcons.check,
                color: colors.onPrimary,
                size: 16,
              )
                  : null,
            ),
            const SizedBox(width: 12),
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value
                    ? accent.withValues(alpha: 0.1)
                    : colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: value ? accent : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
