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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Text(
                'Public Address',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.copy, size: 18, color: c.primary),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  HapticFeedback.lightImpact();
                  showFloatingSnackBar(context, message: 'Address copied', type: SnackBarType.success);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            address,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
