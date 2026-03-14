// lib/features/swap/view/widgets/section_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.border.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
