// lib/features/settings/view/widgets/section_header.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.text, required this.colors});
  final String text;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary.withOpacity(0.8),
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
