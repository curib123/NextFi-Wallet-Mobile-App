import 'package:flutter/material.dart';

/// Centralized color palette for the Blue Fintech / Web3 Wallet app.
/// Designed for modern banking, crypto, and DeFi dashboards.
class AppColor {
  // ─── Brand Colors (Fintech Blue Identity) ───────────────────────────
  final Color primary = const Color(0xFF1565FF);      // Fintech Blue
  final Color primaryDark = const Color(0xFF003ECC);  // Deep Finance Blue
  final Color accent = const Color(0xFF00C2FF);       // Neon Aqua Action

  // ─── Status Colors ──────────────────────────────────────────────────
  final Color success = const Color(0xFF00E676);      // Profit / Success
  final Color warning = const Color(0xFFFFB300);      // Alerts
  final Color error = const Color(0xFFFF3D00);        // Critical / Loss
  final Color info = const Color(0xFF29B6F6);         // Info Blue

  // ─── Neutral Palette (Theme Adaptive) ───────────────────────────────
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  // ─── Crypto / Market Accent Colors ──────────────────────────────────
  final Color chartGreen = const Color(0xFF00E676);
  final Color chartRed = const Color(0xFFFF3D00);

  final Color stellar = const Color(0xFF1565FF);   // Re-mapped to fintech blue
  final Color bitcoin = const Color(0xFFF7931A);
  final Color ethereum = const Color(0xFF627EEA);

  // ─── Gradients ──────────────────────────────────────────────────────

  /// Main brand gradient
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF1565FF), Color(0xFF5B8CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent / action gradient
  final LinearGradient accentGradient = const LinearGradient(
    colors: [Color(0xFF00C2FF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success gradient
  final LinearGradient successGradient = const LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF69F0AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Fintech glass crypto gradient
  final LinearGradient cryptoGradient = const LinearGradient(
    colors: [Color(0xFF1565FF), Color(0xFF00C2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark glassmorphism overlay
  final LinearGradient darkGlassGradient = const LinearGradient(
    colors: [Color(0x1A1565FF), Color(0x0D00C2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Constructors ───────────────────────────────────────────────────
  const AppColor._({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  /// ─── Light Mode (Clean Fintech UI) ──────────────────────────────────
  static const AppColor light = AppColor._(
    background: Color(0xFFF4F7FF),      // Soft blue gray
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0A0F1C),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE3E8F2),
  );

  /// ─── Dark Mode (Neo-Bank / Web3 Style) ──────────────────────────────
  static const AppColor dark = AppColor._(
    background: Color(0xFF05070D),      // Deep fintech dark
    surface: Color(0xFF0F121A),
    textPrimary: Color(0xFFF5F7FF),
    textSecondary: Color(0xFF9AA4B2),
    border: Color(0xFF1C2333),
  );

  /// Get theme-aware colors
  static AppColor of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColor.dark
        : AppColor.light;
  }
}

/// ─── Theme Bridge for runtime theme switching ─────────────────────────
class ThemeBridge {
  static void Function(ThemeMode)? apply;
}
