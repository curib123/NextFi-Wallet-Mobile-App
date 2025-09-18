// lib/features/import_wallet/view/widgets/warning_box_import.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class WarningBox extends StatelessWidget {
  const WarningBox({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Enter your recovery phrase exactly as saved. "
                  "Suggestions will help you auto-complete words.",
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
