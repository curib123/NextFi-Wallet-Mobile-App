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
    Color primaryColor = colors.textSecondary;
    Color bgColor;

    if (count == 12 || count == 24) {
      primaryColor = colors.success;
      bgColor = colors.success.withOpacity(0.1);
    } else if (count > 0) {
      primaryColor = colors.warning;
      bgColor = colors.warning.withOpacity(0.1);
    } else {
      bgColor = colors.surface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count == 12 || count == 24)
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: primaryColor,
            ),
          if (count == 12 || count == 24) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}