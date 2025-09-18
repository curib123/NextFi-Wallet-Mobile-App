// lib/features/receive/view/widgets/address_row.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class AddressRow extends StatelessWidget {
  const AddressRow({super.key, required this.address});
  final String address;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: c.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(LucideIcons.wallet, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              address,
              style: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(LucideIcons.copy, size: 20, color: c.primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              HapticFeedback.lightImpact();
              showFloatingSnackBar(context, message: 'Address copied', type: SnackBarType.success);
            },
          ),
        ],
      ),
    );
  }
}
