// 📂 lib/helper/app_color.dart
import 'package:flutter/material.dart';

/// Centralized color palette for the Fintech app.
/// Supports Light & Dark mode themes.
class AppColor {
  // ─── Brand Colors (same for both themes) ─────────────────────────────
  final Color primary = const Color(0xFF1A73E8); // Fintech Blue
  final Color primaryDark = const Color(0xFF0D47A1); // Darker Blue
  final Color accent = const Color(0xFF00C853); // Growth Green

  // ─── Status Colors ────────────────────────────
  final Color success = const Color(0xFF00E676);
  final Color warning = const Color(0xFFFFA000);
  final Color error = const Color(0xFFD32F2F);
  final Color info = const Color(0xFF0288D1);

  // ─── Neutral Palette (changes with theme) ─────
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  // ─── Gradients ─────────────────────────────────
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
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
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    border: Color(0xFFE0E0E0),
  );

  /// Dark mode colors
  static const AppColor dark = AppColor._(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
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
