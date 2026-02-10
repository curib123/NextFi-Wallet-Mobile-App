// lib/features/auth_gate/view/widgets/biometrics_button.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class BiometricsButton extends StatelessWidget {
  const BiometricsButton({
    super.key,
    required this.maxWidth,
    required this.colors,
    required this.onPressed,
  });

  final double maxWidth;
  final AppColor colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.border.withOpacity(0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint_rounded, color: colors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              "Use Biometrics",
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}