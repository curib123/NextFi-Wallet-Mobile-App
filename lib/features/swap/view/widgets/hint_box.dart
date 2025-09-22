import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class HintBox extends StatelessWidget {
  final String text;
  const HintBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withOpacity(.35)),
      ),
      child: Row(children: [
        Icon(LucideIcons.info, size: 18, color: c.info),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
      ]),
    );
  }
}
