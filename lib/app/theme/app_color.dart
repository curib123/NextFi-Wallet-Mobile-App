import 'package:flutter/material.dart';

class AppColor {
  final Color primary = const Color(0xFF3A5BFF);
  final Color success = const Color(0xFF10B981);
  final Color error = const Color(0xFFEF4444);
  final Color warning = const Color(0xFFF59E0B);

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color onPrimary;

  final Color primaryDark;
  final Color accent;
  final Color info;
  final Color chartGreen;
  final Color chartRed;

  final LinearGradient primaryGradient;
  final LinearGradient surfaceGradient;
  final LinearGradient darkGlassGradient;

  const AppColor._({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.onPrimary,
    required this.primaryDark,
    required this.accent,
    required this.info,
    required this.chartGreen,
    required this.chartRed,
    required this.primaryGradient,
    required this.surfaceGradient,
    required this.darkGlassGradient,
  });

  static const AppColor light = AppColor._(
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    border: Color(0xFFCBD5E1),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF2C46CC),
    accent: Color(0xFFA5B4FC),
    info: Color(0xFF38BDF8),
    chartGreen: Color(0xFF34D399),
    chartRed: Color(0xFFFB7185),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const AppColor dark = AppColor._(
    background: Color(0xFF020617),
    surface: Color(0xFF0F172A),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    border: Color(0xFF1E293B),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF2C46CC),
    accent: Color(0xFFA5B4FC),
    info: Color(0xFF38BDF8),
    chartGreen: Color(0xFF34D399),
    chartRed: Color(0xFFFB7185),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static AppColor of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

class ThemeBridge {
  static void Function(ThemeMode)? apply;
}
