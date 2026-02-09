// lib/features/seed_phrase/view/widgets/meta_header.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.background,
                colors.background.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: colors.border.withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.keyRound,
                size: 18,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '$wordCount-word phrase',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Copy button
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canCopy ? onCopy : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: canCopy
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withOpacity(0.08),
                      colors.primary.withOpacity(0.04),
                    ],
                  )
                      : null,
                  color: canCopy ? null : colors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canCopy
                        ? colors.primary.withOpacity(0.3)
                        : colors.border.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.copy,
                      size: 16,
                      color: canCopy ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Copy',
                      style: TextStyle(
                        color: canCopy ? colors.primary : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Status indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: obscured
                  ? [
                colors.warning.withOpacity(0.12),
                colors.warning.withOpacity(0.06),
              ]
                  : [
                colors.success.withOpacity(0.12),
                colors.success.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: obscured
                  ? colors.warning.withOpacity(0.25)
                  : colors.success.withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: obscured
                    ? colors.warning.withOpacity(0.08)
                    : colors.success.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                obscured ? LucideIcons.lock : LucideIcons.unlock,
                size: 18,
                color: obscured ? colors.warning : colors.success,
              ),
              const SizedBox(width: 8),
              Text(
                obscured ? 'Hidden' : 'Visible',
                style: TextStyle(
                  color: obscured ? colors.warning : colors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}