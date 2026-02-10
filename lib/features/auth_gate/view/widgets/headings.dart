// lib/features/auth_gate/view/widgets/headings.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class Headings extends StatelessWidget {
  const Headings({
    super.key,
    required this.headline,
    required this.subhead,
    required this.colors,
  });

  final String headline;
  final String subhead;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          headline,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subhead,
          style: TextStyle(
            fontSize: 15,
            color: colors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}