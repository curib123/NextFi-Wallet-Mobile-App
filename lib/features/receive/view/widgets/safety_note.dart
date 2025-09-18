// lib/features/receive/view/widgets/safety_note.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class SafetyNote extends StatelessWidget {
  const SafetyNote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.3)),
    );
  }
}
