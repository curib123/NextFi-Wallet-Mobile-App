// lib/features/wallet_creation/view/widgets/glass_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, required this.colors});

  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}
