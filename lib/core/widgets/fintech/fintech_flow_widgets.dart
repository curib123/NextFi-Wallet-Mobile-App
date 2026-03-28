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
    required this.colors,
    this.subtitle,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? subtitle;
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
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                  height: 1.05,
                ),
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
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

class FintechFullBleedSection extends StatelessWidget {
  const FintechFullBleedSection({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
    this.emphasisColor,
  });

  final Widget child;
  final AppColor colors;
  final EdgeInsetsGeometry padding;
  final Color? emphasisColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.42 : 0.68),
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.96 : 0.94),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.9)),
        ),
      ),
      child: child,
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
