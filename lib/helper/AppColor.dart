import 'package:flutter/material.dart';

/// Centralized color palette for the Fintech/Web3 app.
/// Supports Light & Dark mode themes.
class AppColor {
  // ─── Brand Colors (same for both themes) ─────────────────────────────
  final Color primary = const Color(0xFF1A73E8); // Blue
  final Color primaryDark = const Color(0xFF4285F4);  // Lighter Blue for Gradients
  final Color accent = const Color(0xFF9C27B0);       // Purple Accent for Actions

  // ─── Status Colors ────────────────────────────
  final Color success = const Color(0xFF00C853);
  final Color warning = const Color(0xFFFFC107);
  final Color error = const Color(0xFFD32F2F);
  final Color info = const Color(0xFF29B6F6);

  // ─── Neutral Palette (changes with theme) ─────
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  // ─── Gradients ─────────────────────────────────
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final LinearGradient accentGradient = const LinearGradient(
    colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final LinearGradient successGradient = const LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Constructors ─────────────────────────────
  const AppColor._({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  /// Light mode colors
  static const AppColor light = AppColor._(
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF616161),
    border: Color(0xFFBDBDBD),
  );

  /// Dark mode colors
  static const AppColor dark = AppColor._(
    background: Color(0xFF0B0E1A),
    surface: Color(0xFF1B1F2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    border: Color(0xFF2C2C2C),
  );

  /// Get the correct color set based on brightness
  static AppColor of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColor.dark
        : AppColor.light;
  }
}
