import 'package:flutter/material.dart';

/// Tailwind-Inspired Muted Color Palette
/// Calm fintech / wallet / banking UI.
/// Colors sourced directly from Tailwind CSS v3 palette.
class AppColor {
  // ─── Brand Colors ───────────────────────────────────────────────
  // indigo-600 / indigo-700 / indigo-300
  final Color primary = const Color(0xFF3A5BFF);     // Soft Indigo
  final Color primaryDark = const Color(0xFF2C46CC);
  final Color accent      = const Color(0xFFA5B4FC); // indigo-300

  // ─── Status Colors (Tailwind semantic) ─────────────────────────
  // emerald-500 / amber-500 / rose-500 / sky-400
  final Color success = const Color(0xFF10B981); // emerald-500
  final Color warning = const Color(0xFFF59E0B); // amber-500
  final Color error   = const Color(0xFFF43F5E); // rose-500
  final Color info    = const Color(0xFF38BDF8); // sky-400

  // ─── Neutral Palette ───────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color onPrimary;

  // ─── Charts ────────────────────────────────────────────────────
  // emerald-400 / rose-400
  final Color chartGreen = const Color(0xFF34D399); // emerald-400
  final Color chartRed   = const Color(0xFFFB7185); // rose-400

  // ─── Subtle Gradients ──────────────────────────────────────────

  /// Primary gradient — indigo-600 → indigo-400
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [
      Color(0xFF4F46E5), // indigo-600
      Color(0xFF818CF8), // indigo-400
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Surface gradient — white → slate-100
  final LinearGradient surfaceGradient = const LinearGradient(
    colors: [
      Color(0xFFFFFFFF), // white
      Color(0xFFF1F5F9), // slate-100
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark glass gradient — subtle white overlays
  final LinearGradient darkGlassGradient = const LinearGradient(
    colors: [
      Color(0x1AFFFFFF),
      Color(0x0DFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Constructors ──────────────────────────────────────────────
  const AppColor._({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.onPrimary,
  });

  /// ─── Light Mode ───────────────────────────────────────────────
  /// slate-100 bg / slate-200 surface / slate-900 text / slate-500 secondary
  /// slate-200 border
  static const AppColor light = AppColor._(
    background:    Color(0xFFF1F5F9), // slate-100
    surface:       Color(0xFFE2E8F0), // slate-200
    textPrimary:   Color(0xFF0F172A), // slate-900
    textSecondary: Color(0xFF64748B), // slate-500
    border:        Color(0xFFCBD5E1), // slate-300
    onPrimary:     Color(0xFFFFFFFF), // white
  );

  /// ─── Dark Mode ────────────────────────────────────────────────
  /// slate-950 bg / slate-900 surface / slate-50 text / slate-400 secondary
  /// slate-800 border
  static const AppColor dark = AppColor._(
    background:    Color(0xFF020617), // slate-950
    surface:       Color(0xFF0F172A), // slate-900
    textPrimary:   Color(0xFFF8FAFC), // slate-50
    textSecondary: Color(0xFF94A3B8), // slate-400
    border:        Color(0xFF1E293B), // slate-800
    onPrimary:     Color(0xFFFFFFFF), // white
  );

  /// Theme resolver
  static AppColor of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColor.dark
        : AppColor.light;
  }
}

/// ─── Theme Bridge ───────────────────────────────────────────────
class ThemeBridge {
  static void Function(ThemeMode)? apply;
}