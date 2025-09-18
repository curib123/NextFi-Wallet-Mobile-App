// lib/features/import_wallet/view/widgets/word_badge.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class WordBadge extends StatelessWidget {
  const WordBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    String label = "$count words";
    Color tint = colors.background;
    Color text = colors.textSecondary;

    if (count == 12 || count == 24) {
      tint = colors.success.withOpacity(.12);
      text = colors.success;
    } else if (count > 0) {
      tint = colors.warning.withOpacity(.12);
      text = colors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withOpacity(.35)),
      ),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
