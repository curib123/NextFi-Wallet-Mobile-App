// lib/features/wallet_settings/view/widgets/meta_header_refined.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class MetaHeaderSettings extends StatelessWidget {
  const MetaHeaderSettings({super.key, required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

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
                colors.primary.withOpacity(0.12),
                colors.primary.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.primary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.08),
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
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$wordCount-word',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Divider
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.border.withOpacity(0.3),
                  colors.border.withOpacity(0),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Title
        Text(
          "Recovery Phrase",
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}