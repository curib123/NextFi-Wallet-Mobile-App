import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? .2 : .05),
            blurRadius: 16, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
