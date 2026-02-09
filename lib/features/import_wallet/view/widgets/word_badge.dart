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
    LinearGradient gradient;

    if (count == 12 || count == 24) {
      primaryColor = colors.success;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.success.withOpacity(0.15),
          colors.success.withOpacity(0.08),
        ],
      );
    } else if (count > 0) {
      primaryColor = colors.warning;
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.warning.withOpacity(0.15),
          colors.warning.withOpacity(0.08),
        ],
      );
    } else {
      gradient = LinearGradient(
        colors: [
          colors.background,
          colors.background.withOpacity(0.9),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: primaryColor.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: (count == 12 || count == 24)
            ? [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
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
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}