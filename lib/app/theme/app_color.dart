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

  AppColor copyWith({
    Color? primary,
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? onPrimary,
    Color? onSurface,
    Color? primaryDark,
    Color? accent,
    Color? chartGreen,
    Color? chartRed,
    LinearGradient? primaryGradient,
    LinearGradient? surfaceGradient,
    LinearGradient? darkGlassGradient,
  }) {
    return AppColor._(
      primary: primary ?? this.primary,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      onPrimary: onPrimary ?? this.onPrimary,
      onSurface: onSurface ?? this.onSurface,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      chartGreen: chartGreen ?? this.chartGreen,
      chartRed: chartRed ?? this.chartRed,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      darkGlassGradient: darkGlassGradient ?? this.darkGlassGradient,
    );
  }

  // Brand / accent
  static const Color accentBase = Color(0xFF111111);
  static const Color accentDarkBase = Color(0xFFFFFFFF);

  // Semantic colors
  static const Color successBase = Color(0xFF111111);
  static const Color errorBase = Color(0xFF111111);
  static const Color warningBase = Color(0xFF2A2A2A);
  static const Color infoBase = Color(0xFF1C1C1C);

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
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F0F0),
    surfaceOverlay: Color(0xFFFAFAFA),
    border: Color(0xFFD4D4D4),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF555555),
    textMuted: Color(0xFF8A8A8A),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111111),
    chartGreen: Color(0xFF111111),
    chartRed: Color(0xFF555555),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFEDEDED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0xD9FFFFFF), Color(0xBFF0F0F0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const AppColor dark = AppColor._(
    primary: Color(0xFFFFFFFF),
    success: successBase,
    error: errorBase,
    warning: warningBase,
    info: infoBase,
    accent: Color(0xFFFFFFFF),
    primaryDark: accentDarkBase,
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0B),
    surfaceRaised: Color(0xFF161616),
    surfaceOverlay: Color(0xFF111111),
    border: Color(0xFF2B2B2B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCFCFCF),
    textMuted: Color(0xFF8F8F8F),
    onPrimary: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    chartGreen: Color(0xFFFFFFFF),
    chartRed: Color(0xFF8F8F8F),
    primaryGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFD9D9D9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF181818), Color(0xFF050505)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const List<_ThemePalette> themePalettes = <_ThemePalette>[
    _ThemePalette(
      label: 'Monochrome',
      light: _ThemeSpec(
        primary: Color(0xFF000000),
        background: Color(0xFFFFFFFF),
        surface: Color(0xFFF5F5F5),
        surfaceRaised: Color(0xFFF1F1F1),
        surfaceOverlay: Color(0xFFF8F8F8),
        textPrimary: Color(0xFF111111),
        textSecondary: Color(0xFF777777),
        textMuted: Color(0xFF909090),
        border: Color(0xFFE0E0E0),
        accent: Color(0xFF000000),
        primaryDark: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFFFFFFFF),
        background: Color(0xFF000000),
        surface: Color(0xFF0B0B0B),
        surfaceRaised: Color(0xFF171717),
        surfaceOverlay: Color(0xFF101010),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFD4D4D4),
        textMuted: Color(0xFF8F8F8F),
        border: Color(0xFF2E2E2E),
        accent: Color(0xFFFFFFFF),
        primaryDark: Color(0xFFFFFFFF),
        onPrimary: Color(0xFF000000),
      ),
    ),
    _ThemePalette(
      label: 'Midnight Dark',
      light: _ThemeSpec(
        primary: Color(0xFF0F172A),
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFF1F5F9),
        surfaceOverlay: Color(0xFFF8FAFC),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF64748B),
        textMuted: Color(0xFF94A3B8),
        border: Color(0xFFE2E8F0),
        accent: Color(0xFF3B82F6),
        primaryDark: Color(0xFF0F172A),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF0F172A),
        background: Color(0xFF020617),
        surface: Color(0xFF111827),
        surfaceRaised: Color(0xFF172033),
        surfaceOverlay: Color(0xFF0F172A),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFF94A3B8),
        textMuted: Color(0xFF64748B),
        border: Color(0xFF1E293B),
        accent: Color(0xFF3B82F6),
        primaryDark: Color(0xFF3B82F6),
        onPrimary: Color(0xFFFFFFFF),
      ),
    ),
    _ThemePalette(
      label: 'Modern Blue',
      light: _ThemeSpec(
        primary: Color(0xFF2563EB),
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFF1F5F9),
        surfaceOverlay: Color(0xFFF8FAFC),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF64748B),
        textMuted: Color(0xFF94A3B8),
        border: Color(0xFFE2E8F0),
        accent: Color(0xFF3B82F6),
        primaryDark: Color(0xFF1D4ED8),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF3B82F6),
        background: Color(0xFF0B1220),
        surface: Color(0xFF111827),
        surfaceRaised: Color(0xFF172033),
        surfaceOverlay: Color(0xFF101828),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFF94A3B8),
        textMuted: Color(0xFF64748B),
        border: Color(0xFF1E293B),
        accent: Color(0xFF60A5FA),
        primaryDark: Color(0xFF60A5FA),
        onPrimary: Color(0xFFFFFFFF),
      ),
    ),
    _ThemePalette(
      label: 'Ocean Gradient',
      light: _ThemeSpec(
        primary: Color(0xFF0284C7),
        background: Color(0xFFF0F9FF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFE0F2FE),
        surfaceOverlay: Color(0xFFF0F9FF),
        textPrimary: Color(0xFF0C4A6E),
        textSecondary: Color(0xFF0369A1),
        textMuted: Color(0xFF38BDF8),
        border: Color(0xFFBAE6FD),
        accent: Color(0xFF22D3EE),
        primaryDark: Color(0xFF0EA5E9),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF0EA5E9),
        background: Color(0xFF082F49),
        surface: Color(0xFF0C4A6E),
        surfaceRaised: Color(0xFF075985),
        surfaceOverlay: Color(0xFF082F49),
        textPrimary: Color(0xFFE0F2FE),
        textSecondary: Color(0xFFBAE6FD),
        textMuted: Color(0xFF7DD3FC),
        border: Color(0xFF155E75),
        accent: Color(0xFF22D3EE),
        primaryDark: Color(0xFF22D3EE),
        onPrimary: Color(0xFF082F49),
      ),
    ),
    _ThemePalette(
      label: 'Purple Tech',
      light: _ThemeSpec(
        primary: Color(0xFF7C3AED),
        background: Color(0xFFFAF5FF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFF3E8FF),
        surfaceOverlay: Color(0xFFFAF5FF),
        textPrimary: Color(0xFF2E1065),
        textSecondary: Color(0xFF6D28D9),
        textMuted: Color(0xFFA78BFA),
        border: Color(0xFFE9D5FF),
        accent: Color(0xFFC4B5FD),
        primaryDark: Color(0xFF8B5CF6),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF8B5CF6),
        background: Color(0xFF140C2B),
        surface: Color(0xFF22103A),
        surfaceRaised: Color(0xFF2E1065),
        surfaceOverlay: Color(0xFF1A1333),
        textPrimary: Color(0xFFF5F3FF),
        textSecondary: Color(0xFFD8B4FE),
        textMuted: Color(0xFFA78BFA),
        border: Color(0xFF4C1D95),
        accent: Color(0xFFC4B5FD),
        primaryDark: Color(0xFFC4B5FD),
        onPrimary: Color(0xFF140C2B),
      ),
    ),
    _ThemePalette(
      label: 'Emerald Green',
      light: _ThemeSpec(
        primary: Color(0xFF10B981),
        background: Color(0xFFECFDF5),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFD1FAE5),
        surfaceOverlay: Color(0xFFECFDF5),
        textPrimary: Color(0xFF064E3B),
        textSecondary: Color(0xFF047857),
        textMuted: Color(0xFF34D399),
        border: Color(0xFFA7F3D0),
        accent: Color(0xFF34D399),
        primaryDark: Color(0xFF059669),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF10B981),
        background: Color(0xFF022C22),
        surface: Color(0xFF064E3B),
        surfaceRaised: Color(0xFF065F46),
        surfaceOverlay: Color(0xFF033B2E),
        textPrimary: Color(0xFFECFDF5),
        textSecondary: Color(0xFFA7F3D0),
        textMuted: Color(0xFF6EE7B7),
        border: Color(0xFF065F46),
        accent: Color(0xFF34D399),
        primaryDark: Color(0xFF6EE7B7),
        onPrimary: Color(0xFF022C22),
      ),
    ),
    _ThemePalette(
      label: 'Sunset Orange',
      light: _ThemeSpec(
        primary: Color(0xFFF97316),
        background: Color(0xFFFFF7ED),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFFFEDD5),
        surfaceOverlay: Color(0xFFFFF7ED),
        textPrimary: Color(0xFF7C2D12),
        textSecondary: Color(0xFFC2410C),
        textMuted: Color(0xFFFDBA74),
        border: Color(0xFFFED7AA),
        accent: Color(0xFFFDBA74),
        primaryDark: Color(0xFFFB923C),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFFF97316),
        background: Color(0xFF431407),
        surface: Color(0xFF7C2D12),
        surfaceRaised: Color(0xFF9A3412),
        surfaceOverlay: Color(0xFF5B2110),
        textPrimary: Color(0xFFFFF7ED),
        textSecondary: Color(0xFFFED7AA),
        textMuted: Color(0xFFFDBA74),
        border: Color(0xFF9A3412),
        accent: Color(0xFFFDBA74),
        primaryDark: Color(0xFFFED7AA),
        onPrimary: Color(0xFF431407),
      ),
    ),
    _ThemePalette(
      label: 'Cyber Neon',
      light: _ThemeSpec(
        primary: Color(0xFF00F5D4),
        background: Color(0xFFF6FBFF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFEFF6FF),
        surfaceOverlay: Color(0xFFF8FAFC),
        textPrimary: Color(0xFF111827),
        textSecondary: Color(0xFF4B5563),
        textMuted: Color(0xFF6B7280),
        border: Color(0xFFD1D5DB),
        accent: Color(0xFFF15BB5),
        primaryDark: Color(0xFF9B5DE5),
        onPrimary: Color(0xFF111827),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF00F5D4),
        background: Color(0xFF0B0F19),
        surface: Color(0xFF111827),
        surfaceRaised: Color(0xFF1F2937),
        surfaceOverlay: Color(0xFF0F172A),
        textPrimary: Color(0xFFE5E7EB),
        textSecondary: Color(0xFFCBD5E1),
        textMuted: Color(0xFF94A3B8),
        border: Color(0xFF1F2937),
        accent: Color(0xFFF15BB5),
        primaryDark: Color(0xFF9B5DE5),
        onPrimary: Color(0xFF0B0F19),
      ),
    ),
    _ThemePalette(
      label: 'Soft Pastel',
      light: _ThemeSpec(
        primary: Color(0xFFA78BFA),
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFF5F3FF),
        surfaceOverlay: Color(0xFFFDF4FF),
        textPrimary: Color(0xFF334155),
        textSecondary: Color(0xFF64748B),
        textMuted: Color(0xFF94A3B8),
        border: Color(0xFFE2E8F0),
        accent: Color(0xFF93C5FD),
        primaryDark: Color(0xFFFBCFE8),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFFA78BFA),
        background: Color(0xFF1E1B3A),
        surface: Color(0xFF2B254B),
        surfaceRaised: Color(0xFF352F59),
        surfaceOverlay: Color(0xFF241F45),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFE2E8F0),
        textMuted: Color(0xFFCBD5E1),
        border: Color(0xFF4C4A73),
        accent: Color(0xFF93C5FD),
        primaryDark: Color(0xFFFBCFE8),
        onPrimary: Color(0xFF1E1B3A),
      ),
    ),
    _ThemePalette(
      label: 'Luxury Gold',
      light: _ThemeSpec(
        primary: Color(0xFFC9A227),
        background: Color(0xFFFFFBEB),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFFEF3C7),
        surfaceOverlay: Color(0xFFFFFBEB),
        textPrimary: Color(0xFF3F320A),
        textSecondary: Color(0xFF7C6512),
        textMuted: Color(0xFFC9A227),
        border: Color(0xFFFDE68A),
        accent: Color(0xFFFFF3B0),
        primaryDark: Color(0xFFE6C767),
        onPrimary: Color(0xFF111111),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFFC9A227),
        background: Color(0xFF0A0A0A),
        surface: Color(0xFF1A1A1A),
        surfaceRaised: Color(0xFF242424),
        surfaceOverlay: Color(0xFF131313),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFF3E7AE),
        textMuted: Color(0xFFE6C767),
        border: Color(0xFF3A3318),
        accent: Color(0xFFFFF3B0),
        primaryDark: Color(0xFFE6C767),
        onPrimary: Color(0xFF111111),
      ),
    ),
  ];

  static AppColor lightStyle(int index) {
    final spec = themePalettes[normalizeThemeStyleIndex(index)].light;
    return light.copyWith(
      primary: spec.primary,
      background: spec.background,
      surface: spec.surface,
      surfaceRaised: spec.surfaceRaised,
      surfaceOverlay: spec.surfaceOverlay,
      textPrimary: spec.textPrimary,
      textSecondary: spec.textSecondary,
      textMuted: spec.textMuted,
      border: spec.border,
      accent: spec.accent,
      primaryDark: spec.primaryDark,
      success: spec.primary,
      error: spec.primaryDark,
      warning: spec.accent,
      info: spec.primaryDark,
      onPrimary: spec.onPrimary,
      chartGreen: spec.primary,
      chartRed: spec.primaryDark.withValues(alpha: 0.72),
      primaryGradient: LinearGradient(
        colors: <Color>[
          spec.primary,
          spec.primaryDark,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: <Color>[
          spec.surface,
          spec.surfaceRaised,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGlassGradient: LinearGradient(
        colors: <Color>[
          spec.accent.withValues(alpha: 0.12),
          spec.surface.withValues(alpha: 0.92),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static AppColor darkStyle(int index) {
    final spec = themePalettes[normalizeThemeStyleIndex(index)].dark;
    return dark.copyWith(
      primary: spec.primary,
      background: spec.background,
      surface: spec.surface,
      surfaceRaised: spec.surfaceRaised,
      surfaceOverlay: spec.surfaceOverlay,
      textPrimary: spec.textPrimary,
      textSecondary: spec.textSecondary,
      textMuted: spec.textMuted,
      border: spec.border,
      accent: spec.accent,
      primaryDark: spec.primaryDark,
      success: spec.primary,
      error: spec.primaryDark,
      warning: spec.accent,
      info: spec.primaryDark,
      onPrimary: spec.onPrimary,
      chartGreen: spec.primary,
      chartRed: spec.primaryDark.withValues(alpha: 0.72),
      primaryGradient: LinearGradient(
        colors: <Color>[
          spec.primary,
          spec.primaryDark,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: <Color>[
          spec.surfaceRaised,
          spec.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGlassGradient: LinearGradient(
        colors: <Color>[
          spec.accent.withValues(alpha: 0.2),
          spec.surface.withValues(alpha: 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static int normalizeThemeStyleIndex(int index) {
    return ((index % themePalettes.length) + themePalettes.length) %
        themePalettes.length;
  }

  static int get themeStyleCount => themePalettes.length;

  static String themeStyleLabel(int index) {
    return themePalettes[normalizeThemeStyleIndex(index)].label;
  }

  static Color themeStylePreview(int index, Brightness brightness) {
    final palette = themePalettes[normalizeThemeStyleIndex(index)];
    return brightness == Brightness.dark
        ? palette.dark.primary
        : palette.light.primary;
  }

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

  static AppColor fromTheme(ThemeData theme) {
    final brightness = theme.brightness;
    final primary = theme.colorScheme.primary;
    final index = themePalettes.indexWhere((palette) {
      return brightness == Brightness.dark
          ? palette.dark.primary == primary
          : palette.light.primary == primary;
    });
    if (index == -1) {
      return fromBrightness(brightness);
    }
    return brightness == Brightness.dark ? darkStyle(index) : lightStyle(index);
  }

  static AppColor of(BuildContext context) {
    return fromTheme(Theme.of(context));
  }
}

@immutable
class _ThemePalette {
  const _ThemePalette({
    required this.label,
    required this.light,
    required this.dark,
  });

  final String label;
  final _ThemeSpec light;
  final _ThemeSpec dark;
}

@immutable
class _ThemeSpec {
  const _ThemeSpec({
    required this.primary,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.primaryDark,
    required this.onPrimary,
  });

  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color primaryDark;
  final Color onPrimary;
}
