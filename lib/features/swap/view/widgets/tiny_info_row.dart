import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class TinyInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const TinyInfoRow({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(children: [
      Icon(icon, size: 16, color: c.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
    ]);
  }
}
