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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.12)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.info, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
      ]),
    );
  }
}
