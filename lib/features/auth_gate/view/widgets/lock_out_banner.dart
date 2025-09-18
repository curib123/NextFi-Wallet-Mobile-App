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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Text(
        "Too many attempts. Try again in ${_fmt(remaining)}.",
        style: TextStyle(color: Colors.red.shade700),
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
