// lib/features/seed_phrase/view/widgets/meta_header.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';

/// Clean action bar for phrase controls
class MetaHeader extends StatelessWidget {
  const MetaHeader({
    super.key,
    required this.wordCount,
    required this.obscured,
    required this.onCopy,
  });

  final int wordCount;
  final bool obscured;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final canCopy = !obscured;

    return Row(
      children: [
        // Word count badge
        Text(
          '$wordCount words',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // Copy button
        GestureDetector(
          onTap: canCopy ? onCopy : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: canCopy ? colors.surface : colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.copy,
                  size: 16,
                  color: canCopy ? colors.textPrimary : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Copy',
                  style: TextStyle(
                    color: canCopy ? colors.textPrimary : colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Hide button (when visible)
        if (!obscured)
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.eyeOff,
                    size: 16,
                    color: colors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hide',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
