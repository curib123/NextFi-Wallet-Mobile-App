import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class RecipientAddTemplate extends StatelessWidget {
  const RecipientAddTemplate({super.key, required this.address, required this.onAdd});
  final String address;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.12))),
      child: Row(children: [
        Icon(LucideIcons.userPlus, size: 18, color: c.primary),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No saved name for this address', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 12.5)),
        ])),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onAdd,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(color: c.primary.withOpacity(0.35)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            foregroundColor: c.primary,
          ),
          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
