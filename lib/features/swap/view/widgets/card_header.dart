import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

class CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const CardHeader({super.key, required this.icon, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: c.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: c.textSecondary, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
