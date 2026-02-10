// lib/features/send/view/widgets/recipient_loading_line.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientLoadingLine extends StatelessWidget {
  const RecipientLoadingLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.border.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}