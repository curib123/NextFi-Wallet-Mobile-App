import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

Color _mix(Color a, Color b, double amount) => Color.lerp(a, b, amount) ?? a;

class FintechFlowBackground extends StatelessWidget {
  const FintechFlowBackground({
    super.key,
    required this.child,
    required this.colors,
  });

  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.background,
                _mix(colors.background, colors.surfaceOverlay, 0.75),
                _mix(colors.background, colors.surfaceRaised, 0.35),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -40,
          child: _GlowOrb(
            color: colors.primary,
            size: 220,
            opacity: isDark ? 0.18 : 0.12,
          ),
        ),
        Positioned(
          top: 180,
          left: -70,
          child: _GlowOrb(
            color: colors.accent,
            size: 180,
            opacity: isDark ? 0.13 : 0.08,
          ),
        ),
        Positioned(
          bottom: -90,
          right: 20,
          child: _GlowOrb(
            color: colors.primaryDark,
            size: 180,
            opacity: isDark ? 0.12 : 0.06,
          ),
        ),
        child,
      ],
    );
  }
}

class FintechSectionIntro extends StatelessWidget {
  const FintechSectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final AppColor colors;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((eyebrow ?? '').trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    eyebrow!,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.55,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class FintechSurfaceCard extends StatelessWidget {
  const FintechSurfaceCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.all(20),
    this.emphasisColor,
  });

  final Widget child;
  final AppColor colors;
  final EdgeInsetsGeometry padding;
  final Color? emphasisColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = emphasisColor ?? colors.primary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _mix(colors.surface, colors.surfaceRaised, isDark ? 0.78 : 0.35),
            _mix(colors.surface, accent, isDark ? 0.06 : 0.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _mix(colors.border, accent, isDark ? 0.2 : 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : colors.textPrimary).withValues(
              alpha: isDark ? 0.18 : 0.06,
            ),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FintechBottomActionShell extends StatelessWidget {
  const FintechBottomActionShell({
    super.key,
    required this.child,
    required this.colors,
  });

  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.96 : 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : colors.textPrimary).withValues(
              alpha: isDark ? 0.24 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
