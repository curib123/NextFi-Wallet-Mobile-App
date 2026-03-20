import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

class RecipientLoadingLine extends StatelessWidget {
  const RecipientLoadingLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? c.textPrimary : c.surface;
    final borderColor = isDark ? c.textPrimary : c.border;
    final spinnerColor = isDark ? c.primary : c.primary;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: spinnerColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Looking up address…',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
