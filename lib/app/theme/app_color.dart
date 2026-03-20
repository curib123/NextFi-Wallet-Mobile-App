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

  static const Color accentBase = Color(0xFF3A5BFF);
  static const Color successBase = Color(0xFF10B981);
  static const Color errorBase = Color(0xFFEF4444);
  static const Color warningBase = Color(0xFFF59E0B);
  static const Color infoBase = Color(0xFF38BDF8);

  static const AppColor light = AppColor._(
    primary: accentBase,
    success: successBase,
    error: errorBase,
    warning: warningBase,
    info: infoBase,
    accent: Color(0xFFA5B4FC),
    primaryDark: Color(0xFF2C46CC),
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
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
    primary: accentBase,
    success: successBase,
    error: errorBase,
    warning: warningBase,
    info: infoBase,
    accent: Color(0xFFA5B4FC),
    primaryDark: Color(0xFF0C1419),
    background: Color(0xFF0C1419),
    surface: Color(0xFF101419),
    surfaceRaised: Color(0xFF12161D),
    surfaceOverlay: Color(0xFF0E131A),
    border: Color(0xFF1E293B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFFF8FAFC),
    chartGreen: Color(0xFF34D399),
    chartRed: Color(0xFFFB7185),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    darkGlassGradient: LinearGradient(
      colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const List<_ThemePalette> _themePalettes = <_ThemePalette>[
    _ThemePalette(
      label: 'Midnight Blue',
      light: _ThemeSpec(
        primary: Color(0xFF1E3A5F),
        primaryDark: Color(0xFF122340),
        accent: Color(0xFF4A90D9),
        background: Color(0xFFF0F4F8),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFE8EEF5),
        surfaceOverlay: Color(0xFFF5F8FB),
        border: Color(0xFFCDD5E0),
        textPrimary: Color(0xFF0D1B2A),
        textSecondary: Color(0xFF4A6080),
        textMuted: Color(0xFF8AA0B8),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF4E88C8),
        primaryDark: Color(0xFF6AA0DC),
        accent: Color(0xFF628DB8),
        background: Color(0xFF060A0F),
        surfaceOverlay: Color(0xFF090E15),
        surface: Color(0xFF0D1520),
        surfaceRaised: Color(0xFF172030),
        border: Color(0xFF1E2D42),
        textPrimary: Color(0xFFCCD8E8),
        textSecondary: Color(0xFF4E6880),
        textMuted: Color(0xFF253040),
        onPrimary: Color(0xFF060A0F),
      ),
    ),

    _ThemePalette(
      label: 'Electric Blue',
      light: _ThemeSpec(
        primary: Color(0xFF2563EB),
        primaryDark: Color(0xFF1D4ED8),
        accent: Color(0xFF60A5FA),
        background: Color(0xFFF0F5FF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFE8F0FF),
        surfaceOverlay: Color(0xFFF5F8FF),
        border: Color(0xFFBFD3F8),
        textPrimary: Color(0xFF0C1A3D),
        textSecondary: Color(0xFF3B5998),
        textMuted: Color(0xFF7A9CC8),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF4578D8),
        primaryDark: Color(0xFF5A8EE8),
        accent: Color(0xFF6898CC),
        background: Color(0xFF05070E),
        surfaceOverlay: Color(0xFF080B14),
        surface: Color(0xFF0C1020),
        surfaceRaised: Color(0xFF161C30),
        border: Color(0xFF1C2540),
        textPrimary: Color(0xFFCCD5EE),
        textSecondary: Color(0xFF486080),
        textMuted: Color(0xFF243050),
        onPrimary: Color(0xFF05070E),
      ),
    ),

    _ThemePalette(
      label: 'Ocean Blue',
      light: _ThemeSpec(
        primary: Color(0xFF0284C7),
        primaryDark: Color(0xFF0369A1),
        accent: Color(0xFF22D3EE),
        background: Color(0xFFEFF9FF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFE0F4FF),
        surfaceOverlay: Color(0xFFF5FBFF),
        border: Color(0xFFBAE6FD),
        textPrimary: Color(0xFF0A2E47),
        textSecondary: Color(0xFF0C5A80),
        textMuted: Color(0xFF5BA8CC),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF1090CC),
        primaryDark: Color(0xFF28AADC),
        accent: Color(0xFF1498A8),
        background: Color(0xFF03090E),
        surfaceOverlay: Color(0xFF060C13),
        surface: Color(0xFF091420),
        surfaceRaised: Color(0xFF131E2E),
        border: Color(0xFF182838),
        textPrimary: Color(0xFFC0D8EE),
        textSecondary: Color(0xFF386878),
        textMuted: Color(0xFF1C3040),
        onPrimary: Color(0xFF03090E),
      ),
    ),

    _ThemePalette(
      label: 'Cobalt Blue',
      light: _ThemeSpec(
        primary: Color(0xFF1247D6),
        primaryDark: Color(0xFF0E39AF),
        accent: Color(0xFF7AA7FF),
        background: Color(0xFFF2F6FF),
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFE7EEFF),
        surfaceOverlay: Color(0xFFF7FAFF),
        border: Color(0xFFC8D8FF),
        textPrimary: Color(0xFF0C1D4A),
        textSecondary: Color(0xFF355FAF),
        textMuted: Color(0xFF7F99D0),
        onPrimary: Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary: Color(0xFF376CFF),
        primaryDark: Color(0xFF5B87FF),
        accent: Color(0xFF84A8FF),
        background: Color(0xFF050914),
        surfaceOverlay: Color(0xFF08101D),
        surface: Color(0xFF0C1528),
        surfaceRaised: Color(0xFF16213A),
        border: Color(0xFF22304F),
        textPrimary: Color(0xFFD8E3FF),
        textSecondary: Color(0xFF6784BF),
        textMuted: Color(0xFF2D3F63),
        onPrimary: Color(0xFF040812),
      ),
    ),
  ];

  static AppColor lightStyle(int index) {
    final palette = _themePalettes[normalizeThemeStyleIndex(index)];
    return light.copyWith(
      primary: palette.light.primary,
      primaryDark: palette.light.primaryDark,
      accent: palette.light.accent,
      background: palette.light.background,
      surface: palette.light.surface,
      surfaceRaised: palette.light.surfaceRaised,
      surfaceOverlay: palette.light.surfaceOverlay,
      border: palette.light.border,
      textPrimary: palette.light.textPrimary,
      textSecondary: palette.light.textSecondary,
      textMuted: palette.light.textMuted,
      onPrimary: palette.light.onPrimary,
      onSurface: palette.light.textPrimary,
      primaryGradient: LinearGradient(
        colors: [palette.light.primary, palette.light.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [palette.light.surface, palette.light.background],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGlassGradient: LinearGradient(
        colors: [
          palette.light.primary.withValues(alpha: 0.08),
          palette.light.primary.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static AppColor darkStyle(int index) {
    final palette = _themePalettes[normalizeThemeStyleIndex(index)];
    return dark.copyWith(
      primary: palette.dark.primary,
      primaryDark: palette.dark.primaryDark,
      accent: palette.dark.accent,
      background: palette.dark.background,
      surface: palette.dark.surface,
      surfaceRaised: palette.dark.surfaceRaised,
      surfaceOverlay: palette.dark.surfaceOverlay,
      border: palette.dark.border,
      textPrimary: palette.dark.textPrimary,
      textSecondary: palette.dark.textSecondary,
      textMuted: palette.dark.textMuted,
      onPrimary: palette.dark.onPrimary,
      onSurface: palette.dark.textPrimary,
      primaryGradient: LinearGradient(
        colors: [palette.dark.primary, palette.dark.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surfaceGradient: LinearGradient(
        colors: [palette.dark.surfaceRaised, palette.dark.background],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      darkGlassGradient: LinearGradient(
        colors: [
          palette.dark.primary.withValues(alpha: 0.15),
          palette.dark.primary.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static int normalizeThemeStyleIndex(int index) {
    return ((index % _themePalettes.length) + _themePalettes.length) %
        _themePalettes.length;
  }

  static int get themeStyleCount => _themePalettes.length;

  static String themeStyleLabel(int index) {
    return _themePalettes[normalizeThemeStyleIndex(index)].label;
  }

  static Color themeStylePreview(int index, Brightness brightness) {
    final palette = _themePalettes[normalizeThemeStyleIndex(index)];
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

  static AppColor fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static AppColor fromTheme(ThemeData theme) {
    final brightness = theme.brightness;
    final primary = theme.colorScheme.primary;
    final index = _themePalettes.indexWhere((palette) {
      return brightness == Brightness.dark
          ? palette.dark.primary == primary
          : palette.light.primary == primary;
    });
    if (index == -1) return fromBrightness(brightness);
    return brightness == Brightness.dark ? darkStyle(index) : lightStyle(index);
  }

  static AppColor of(BuildContext context) => fromTheme(Theme.of(context));
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
    required this.primaryDark,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onPrimary,
  });

  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color onPrimary;
}
