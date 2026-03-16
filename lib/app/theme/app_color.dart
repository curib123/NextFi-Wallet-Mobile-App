import 'package:flutter/material.dart';

@immutable
class AppColor {
  const AppColor._({
    required this.primary,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.onPrimary,
    required this.onSurface,
    required this.primaryDark,
    required this.accent,
    required this.chartGreen,
    required this.chartRed,
    required this.primaryGradient,
    required this.surfaceGradient,
    required this.darkGlassGradient,
  });

  // Brand / accent
  static const Color accentBase = Color(0xFF2563EB);
  static const Color accentDarkBase = Color(0xFF1D4ED8);

  // Semantic colors
  static const Color successBase = Color(0xFF16C784);
  static const Color errorBase = Color(0xFFEF4444);
  static const Color warningBase = Color(0xFFF59E0B);
  static const Color infoBase = Color(0xFF3B82F6);

  static const Color brandPrimary = accentBase;
  static const Color brandPrimaryDark = accentDarkBase;

  static const AppColor light = AppColor._(
    primary: accentBase,
    success: successBase,
    error: errorBase,
    warning: warningBase,
    info: infoBase,
    accent: accentBase,
    primaryDark: accentDarkBase,
    background: Color(0xFFF7F7F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F3F5),
    surfaceOverlay: Color(0xFFFDFDFD),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111111),
    chartGreen: successBase,
    chartRed: errorBase,
    primaryGradient: LinearGradient(
      colors: [accentBase, Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F3F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0xCCFFFFFF), Color(0xB3F7F7F7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const AppColor dark = AppColor._(
    primary: accentBase,
    success: successBase,
    error: errorBase,
    warning: warningBase,
    info: infoBase,
    accent: accentBase,
    primaryDark: accentDarkBase,
    background: Color(0xFF07111F),
    surface: Color(0xFF0E1A2B),
    surfaceRaised: Color(0xFF16253A),
    surfaceOverlay: Color(0xFF0B1625),
    border: Color(0xFF23354F),
    textPrimary: Color(0xFFF4F8FF),
    textSecondary: Color(0xFFB4C2D9),
    textMuted: Color(0xFF6F829F),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFFF4F8FF),
    chartGreen: successBase,
    chartRed: errorBase,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF4F8CFF), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF16253A), Color(0xFF0A1321)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0x224F8CFF), Color(0x0CF4F8FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  final Color primary;
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color onPrimary;
  final Color onSurface;
  final Color primaryDark;
  final Color accent;
  final Color chartGreen;
  final Color chartRed;
  final LinearGradient primaryGradient;
  final LinearGradient surfaceGradient;
  final LinearGradient darkGlassGradient;

  static AppColor fromBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static AppColor of(BuildContext context) {
    return fromBrightness(Theme.of(context).brightness);
  }
}
