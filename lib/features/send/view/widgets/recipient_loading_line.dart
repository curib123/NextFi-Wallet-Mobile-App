// lib/features/send/view/widgets/recipient_loading_line.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientLoadingLine extends StatelessWidget {
  const RecipientLoadingLine({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}