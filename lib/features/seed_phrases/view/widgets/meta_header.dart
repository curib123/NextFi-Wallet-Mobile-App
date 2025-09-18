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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border.withOpacity(.25)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.keyRound, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text('$wordCount-word phrase',
                  style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: canCopy ? onCopy : null,
          icon: const Icon(LucideIcons.copy, size: 14),
          label: const Text('Copy', style: TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: canCopy ? colors.primary : colors.textSecondary,
            side: BorderSide(
              color: canCopy ? colors.primary : colors.border.withOpacity(.7),
              width: 1,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Icon(obscured ? LucideIcons.lock : LucideIcons.unlock,
                size: 16, color: obscured ? colors.warning : colors.success),
            const SizedBox(width: 6),
            Text(obscured ? 'Hidden' : 'Visible',
                style: TextStyle(
                  color: obscured ? colors.warning : colors.success,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ],
    );
  }
}
