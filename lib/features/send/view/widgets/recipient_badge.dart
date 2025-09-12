import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

class RecipientBadge extends StatelessWidget {
  const RecipientBadge({
    super.key,
    required this.name,
    required this.colorValue,
    required this.address,
    required this.onEdit,
  });

  final String name;
  final int colorValue;
  final String address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final color = Color(colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.18))),
      child: Row(children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 12.5)),
        ])),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(LucideIcons.edit, size: 16),
          label: const Text('Edit'),
          style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]),
    );
  }
}
