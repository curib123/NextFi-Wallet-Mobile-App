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
        color: c.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}