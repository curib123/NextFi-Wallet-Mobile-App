// lib/features/auth_gate/view/widgets/biometrics_button.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

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
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onPressed,
            icon: Icon(Icons.fingerprint_rounded, color: colors.primary),
            label: const Text("Use Biometrics"),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
