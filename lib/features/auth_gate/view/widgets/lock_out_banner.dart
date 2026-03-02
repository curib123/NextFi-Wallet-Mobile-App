// lib/features/auth_gate/view/widgets/lockout_banner.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class LockoutBanner extends StatelessWidget {
  const LockoutBanner({super.key, required this.remaining, required this.colors});
  final Duration remaining;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        "Too many attempts. Try again in ${_fmt(remaining)}.",
        style: TextStyle(
          color: colors.error,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}