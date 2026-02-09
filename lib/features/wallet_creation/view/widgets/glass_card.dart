// lib/features/wallet_creation/view/widgets/glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    required this.colors,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final AppColor colors;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withOpacity(.7),
            colors.surface.withOpacity(.5),
          ],
        ),
        border: Border.all(
          color: colors.primary.withOpacity(.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface.withOpacity(.85),
                  colors.surface.withOpacity(.75),
                ],
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}