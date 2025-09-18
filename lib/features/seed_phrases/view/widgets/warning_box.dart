// lib/features/seed_phrase/view/widgets/warning_box.dart
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: colors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: colors.textPrimary, fontSize: 13.2, height: 1.45),
                children: [
                  TextSpan(
                    text: "Keep your recovery phrase safe.\n",
                    style: TextStyle(color: colors.warning, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                    "It’s the only way to access your funds. Do not share it with anyone. "
                        "NextFi never stores your keys—you are in full control.",
                    style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w400, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
