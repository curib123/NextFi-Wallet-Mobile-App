// lib/features/wallet_settings/view/widgets/meta_header_settings.dart
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
        Text("Recovery Phrase",
            style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: .2)),
      ],
    );
  }
}
