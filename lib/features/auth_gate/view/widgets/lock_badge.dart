// lib/features/auth_gate/view/widgets/lock_badge.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class LockBadge extends StatelessWidget {
  const LockBadge({super.key, required this.unlocked, required this.colors});
  final bool unlocked;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          key: ValueKey<bool>(unlocked),
          size: 80,
          color: colors.primary,
        ),
      ),
    );
  }
}
