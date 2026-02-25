// lib/features/send/view/widgets/recipient_loading_line.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientLoadingLine extends StatelessWidget {
  const RecipientLoadingLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solid surface tint — no opacity
    final bgColor = isDark ? const Color(0xFF171923) : const Color(0xFFE8EBEF);
    final borderColor = isDark ? const Color(0xFF252A38) : const Color(0xFFD8DCE4);
    final spinnerColor = isDark ? const Color(0xFF4D6AFF) : const Color(0xFF3A5BFF);

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