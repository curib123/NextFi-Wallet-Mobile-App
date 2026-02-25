import 'package:flutter/material.dart';

/// Minimalist Muted Color Palette
/// Calm fintech / wallet / banking UI (non-glowy).
class AppColor {
  // ─── Brand Colors (Muted Identity) ─────────────────────────────
  final Color primary = const Color(0xFF3A5BFF);     // Soft Indigo
  final Color primaryDark = const Color(0xFF2C46CC); // Muted deep indigo
  final Color accent = const Color(0xFF8B9DC3);      // Grayish blue accent

  // ─── Status Colors (Softened) ──────────────────────────────────
  final Color success = const Color(0xFF34C759); // iOS green style
  final Color warning = const Color(0xFFFF9F0A); // Soft orange
  final Color error = const Color(0xFFFF453A);   // Soft red
  final Color info = const Color(0xFF5AC8FA);    // Calm sky blue

  // ─── Neutral Palette ───────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color onPrimary;

  // ─── Charts ────────────────────────────────────────────────────
  final Color chartGreen = const Color(0xFF30D158);
  final Color chartRed = const Color(0xFFFF453A);

  // ─── Subtle Gradients (Very soft) ──────────────────────────────

  /// Primary subtle gradient
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [
      Color(0xFF3A5BFF),
      Color(0xFF6F86FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Surface gradient
  final LinearGradient surfaceGradient = const LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF2F4F8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark subtle gradient
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
  static const AppColor light = AppColor._(
    background: Color(0xFFF1F3F6),   // Neutral gray white
    surface: Color(0xFFE6E8EC),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    onPrimary: Color(0xFFFFFFFF),
  );

  /// ─── Dark Mode ────────────────────────────────────────────────
  static const AppColor dark = AppColor._(
    background: Color(0xFF0F1115),   // Soft dark
    surface: Color(0xFF171923),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    border: Color(0xFF2A2F3A),
    onPrimary: Color(0xFFFFFFFF),
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
