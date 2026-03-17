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

  // ─── Brand / semantic base colors ────────────────────────────────────────
  static const Color accentBase    = Color(0xFF3A5BFF);
  static const Color successBase   = Color(0xFF10B981);
  static const Color errorBase     = Color(0xFFEF4444);
  static const Color warningBase   = Color(0xFFF59E0B);
  static const Color infoBase      = Color(0xFF38BDF8);

  // ─── Default light theme ──────────────────────────────────────────────────
  static const AppColor light = AppColor._(
    primary:        accentBase,
    success:        successBase,
    error:          errorBase,
    warning:        warningBase,
    info:           infoBase,
    accent:         Color(0xFFA5B4FC),
    primaryDark:    Color(0xFF2C46CC),
    background:     Color(0xFFF1F5F9),
    surface:        Color(0xFFFFFFFF),
    surfaceRaised:  Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFF1F5F9),
    border:         Color(0xFFCBD5E1),
    textPrimary:    Color(0xFF0F172A),
    textSecondary:  Color(0xFF64748B),
    textMuted:      Color(0xFF94A3B8),
    onPrimary:      Color(0xFFFFFFFF),
    onSurface:      Color(0xFF0F172A),
    chartGreen:     Color(0xFF34D399),
    chartRed:       Color(0xFFFB7185),
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

  // ─── Default dark theme ───────────────────────────────────────────────────
  static const AppColor dark = AppColor._(
    primary:        accentBase,
    success:        successBase,
    error:          errorBase,
    warning:        warningBase,
    info:           infoBase,
    accent:         Color(0xFFA5B4FC),
    primaryDark:    Color(0xFF0C1419),
    background:     Color(0xFF0C1419),
    surface:        Color(0xFF101419),
    surfaceRaised:  Color(0xFF12161D),
    surfaceOverlay: Color(0xFF0E131A),
    border:         Color(0xFF1E293B),
    textPrimary:    Color(0xFFF8FAFC),
    textSecondary:  Color(0xFF94A3B8),
    textMuted:      Color(0xFF64748B),
    onPrimary:      Color(0xFFFFFFFF),
    onSurface:      Color(0xFFF8FAFC),
    chartGreen:     Color(0xFF34D399),
    chartRed:       Color(0xFFFB7185),
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

  // ─── Named palettes ───────────────────────────────────────────────────────
  //
  // Dark mode surface system — strict brightness budget:
  //
  //   background    hex R channel ≤ 0x0A  (≤ 4% luminance)
  //   surfaceOverlay               +0x03  (barely lifted)
  //   surface                      +0x06  (card base — clearly distinct)
  //   surfaceRaised                +0x0A  (sheet / elevated card — clearly distinct)
  //   border                       +0x0C  (hairline only, never flashy)
  //
  //   textPrimary   max 88% brightness  — not pure white, eases eye strain
  //   textSecondary max 45% brightness  — clearly secondary, not competing
  //   textMuted     max 25% brightness  — hint-level only
  //
  static const List<_ThemePalette> themePalettes = <_ThemePalette>[

    // 0 ── Monochrome ─────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Monochrome',
      light: _ThemeSpec(
        primary:        Color(0xFF111111),
        primaryDark:    Color(0xFF000000),
        accent:         Color(0xFF555555),
        background:     Color(0xFFF7F7F7),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFEFEFEF),
        surfaceOverlay: Color(0xFFF3F3F3),
        border:         Color(0xFFDDDDDD),
        textPrimary:    Color(0xFF111111),
        textSecondary:  Color(0xFF555555),
        textMuted:      Color(0xFF999999),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFFCCCCCC),
        primaryDark:    Color(0xFFDDDDDD),
        accent:         Color(0xFF707070),
        background:     Color(0xFF080808),
        surfaceOverlay: Color(0xFF0B0B0B),
        surface:        Color(0xFF111111),
        surfaceRaised:  Color(0xFF1B1B1B),
        border:         Color(0xFF272727),
        textPrimary:    Color(0xFFE0E0E0),
        textSecondary:  Color(0xFF707070),
        textMuted:      Color(0xFF383838),
        onPrimary:      Color(0xFF080808),
      ),
    ),

    // 1 ── Midnight Slate ─────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Midnight Slate',
      light: _ThemeSpec(
        primary:        Color(0xFF1E3A5F),
        primaryDark:    Color(0xFF122340),
        accent:         Color(0xFF4A90D9),
        background:     Color(0xFFF0F4F8),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFE8EEF5),
        surfaceOverlay: Color(0xFFF5F8FB),
        border:         Color(0xFFCDD5E0),
        textPrimary:    Color(0xFF0D1B2A),
        textSecondary:  Color(0xFF4A6080),
        textMuted:      Color(0xFF8AA0B8),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF4E88C8),
        primaryDark:    Color(0xFF6AA0DC),
        accent:         Color(0xFF628DB8),
        background:     Color(0xFF060A0F),
        surfaceOverlay: Color(0xFF090E15),
        surface:        Color(0xFF0D1520),
        surfaceRaised:  Color(0xFF172030),
        border:         Color(0xFF1E2D42),
        textPrimary:    Color(0xFFCCD8E8),
        textSecondary:  Color(0xFF4E6880),
        textMuted:      Color(0xFF253040),
        onPrimary:      Color(0xFF060A0F),
      ),
    ),

    // 2 ── Modern Blue ─────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Modern Blue',
      light: _ThemeSpec(
        primary:        Color(0xFF2563EB),
        primaryDark:    Color(0xFF1D4ED8),
        accent:         Color(0xFF60A5FA),
        background:     Color(0xFFF0F5FF),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFE8F0FF),
        surfaceOverlay: Color(0xFFF5F8FF),
        border:         Color(0xFFBFD3F8),
        textPrimary:    Color(0xFF0C1A3D),
        textSecondary:  Color(0xFF3B5998),
        textMuted:      Color(0xFF7A9CC8),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF4578D8),
        primaryDark:    Color(0xFF5A8EE8),
        accent:         Color(0xFF6898CC),
        background:     Color(0xFF05070E),
        surfaceOverlay: Color(0xFF080B14),
        surface:        Color(0xFF0C1020),
        surfaceRaised:  Color(0xFF161C30),
        border:         Color(0xFF1C2540),
        textPrimary:    Color(0xFFCCD5EE),
        textSecondary:  Color(0xFF486080),
        textMuted:      Color(0xFF243050),
        onPrimary:      Color(0xFF05070E),
      ),
    ),

    // 3 ── Ocean Gradient ──────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Ocean Gradient',
      light: _ThemeSpec(
        primary:        Color(0xFF0284C7),
        primaryDark:    Color(0xFF0369A1),
        accent:         Color(0xFF22D3EE),
        background:     Color(0xFFEFF9FF),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFE0F4FF),
        surfaceOverlay: Color(0xFFF5FBFF),
        border:         Color(0xFFBAE6FD),
        textPrimary:    Color(0xFF0A2E47),
        textSecondary:  Color(0xFF0C5A80),
        textMuted:      Color(0xFF5BA8CC),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF1090CC),
        primaryDark:    Color(0xFF28AADC),
        accent:         Color(0xFF1498A8),
        background:     Color(0xFF03090E),
        surfaceOverlay: Color(0xFF060C13),
        surface:        Color(0xFF091420),
        surfaceRaised:  Color(0xFF131E2E),
        border:         Color(0xFF182838),
        textPrimary:    Color(0xFFC0D8EE),
        textSecondary:  Color(0xFF386878),
        textMuted:      Color(0xFF1C3040),
        onPrimary:      Color(0xFF03090E),
      ),
    ),

    // 4 ── Purple Tech ─────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Purple Tech',
      light: _ThemeSpec(
        primary:        Color(0xFF7C3AED),
        primaryDark:    Color(0xFF6D28D9),
        accent:         Color(0xFFA78BFA),
        background:     Color(0xFFF7F3FF),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFEEE6FF),
        surfaceOverlay: Color(0xFFFBF8FF),
        border:         Color(0xFFDDD0FF),
        textPrimary:    Color(0xFF1A0A3D),
        textSecondary:  Color(0xFF5B3A9E),
        textMuted:      Color(0xFF9B80CC),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF7850D0),
        primaryDark:    Color(0xFF9068E0),
        accent:         Color(0xFF9878C8),
        background:     Color(0xFF060410),
        surfaceOverlay: Color(0xFF090718),
        surface:        Color(0xFF0E0B22),
        surfaceRaised:  Color(0xFF181430),
        border:         Color(0xFF201A3C),
        textPrimary:    Color(0xFFCCC0E8),
        textSecondary:  Color(0xFF503C70),
        textMuted:      Color(0xFF281E40),
        onPrimary:      Color(0xFF060410),
      ),
    ),

    // 5 ── Emerald Green ───────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Emerald Green',
      light: _ThemeSpec(
        primary:        Color(0xFF059669),
        primaryDark:    Color(0xFF047857),
        accent:         Color(0xFF34D399),
        background:     Color(0xFFEAFBF4),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFFAFAFA),
        surfaceOverlay: Color(0xFFF3FDF8),
        border:         Color(0xFFA7E8CD),
        textPrimary:    Color(0xFF052E1C),
        textSecondary:  Color(0xFF1A6645),
        textMuted:      Color(0xFF5AA87D),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF0C9860),
        primaryDark:    Color(0xFF18B078),
        accent:         Color(0xFF209868),
        background:     Color(0xFF020806),
        surfaceOverlay: Color(0xFF050B08),
        surface:        Color(0xFF091410),
        surfaceRaised:  Color(0xFF131E18),
        border:         Color(0xFF182820),
        textPrimary:    Color(0xFFC0DCCC),
        textSecondary:  Color(0xFF306848),
        textMuted:      Color(0xFF183828),
        onPrimary:      Color(0xFF020806),
      ),
    ),

    // 6 ── Sunset Orange ───────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Sunset Orange',
      light: _ThemeSpec(
        primary:        Color(0xFFEA6C00),
        primaryDark:    Color(0xFFC85A00),
        accent:         Color(0xFFFBB040),
        background:     Color(0xFFFFF6EC),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFFFEDD5),
        surfaceOverlay: Color(0xFFFFFAF5),
        border:         Color(0xFFFFCFA0),
        textPrimary:    Color(0xFF2D1200),
        textSecondary:  Color(0xFF8B3E00),
        textMuted:      Color(0xFFC48050),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFFC06010),
        primaryDark:    Color(0xFFD87020),
        accent:         Color(0xFFA87020),
        background:     Color(0xFF090400),
        surfaceOverlay: Color(0xFF0D0700),
        surface:        Color(0xFF130C00),
        surfaceRaised:  Color(0xFF1D1400),
        border:         Color(0xFF261A00),
        textPrimary:    Color(0xFFDDC8A8),
        textSecondary:  Color(0xFF705020),
        textMuted:      Color(0xFF3A2808),
        onPrimary:      Color(0xFF090400),
      ),
    ),

    // 7 ── Cyber Neon ──────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Cyber Neon',
      light: _ThemeSpec(
        primary:        Color(0xFF00B8A0),
        primaryDark:    Color(0xFF007D6D),
        accent:         Color(0xFFE040C8),
        background:     Color(0xFFF0FEFE),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFDFFFFA),
        surfaceOverlay: Color(0xFFF5FFFE),
        border:         Color(0xFFAAE8E0),
        textPrimary:    Color(0xFF001A17),
        textSecondary:  Color(0xFF1A6860),
        textMuted:      Color(0xFF60ACA5),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF00A890),
        primaryDark:    Color(0xFF00BCA0),
        accent:         Color(0xFFA82890),
        background:     Color(0xFF020608),
        surfaceOverlay: Color(0xFF05090C),
        surface:        Color(0xFF080F12),
        surfaceRaised:  Color(0xFF12191C),
        border:         Color(0xFF182428),
        textPrimary:    Color(0xFFB8D8D0),
        textSecondary:  Color(0xFF286858),
        textMuted:      Color(0xFF143028),
        onPrimary:      Color(0xFF020608),
      ),
    ),

    // 8 ── Soft Pastel ─────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Soft Pastel',
      light: _ThemeSpec(
        primary:        Color(0xFF9B72CF),
        primaryDark:    Color(0xFF7D52B0),
        accent:         Color(0xFFF9A8D4),
        background:     Color(0xFFFBF7FF),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFF3EEFF),
        surfaceOverlay: Color(0xFFFEFBFF),
        border:         Color(0xFFE4D5F5),
        textPrimary:    Color(0xFF221640),
        textSecondary:  Color(0xFF6A4A90),
        textMuted:      Color(0xFFAA90CC),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF7858B8),
        primaryDark:    Color(0xFF8E70CC),
        accent:         Color(0xFFA86898),
        background:     Color(0xFF07050F),
        surfaceOverlay: Color(0xFF0A0815),
        surface:        Color(0xFF0F0C1E),
        surfaceRaised:  Color(0xFF19162C),
        border:         Color(0xFF201C38),
        textPrimary:    Color(0xFFCCC0E0),
        textSecondary:  Color(0xFF4E3C68),
        textMuted:      Color(0xFF281E38),
        onPrimary:      Color(0xFF07050F),
      ),
    ),

    // 9 ── Luxury Gold ─────────────────────────────────────────────────────────
    _ThemePalette(
      label: 'Luxury Gold',
      light: _ThemeSpec(
        primary:        Color(0xFFB8860B),
        primaryDark:    Color(0xFF8B6508),
        accent:         Color(0xFFE8C84A),
        background:     Color(0xFFFFFCF0),
        surface:        Color(0xFFFFFFFF),
        surfaceRaised:  Color(0xFFFFF5D6),
        surfaceOverlay: Color(0xFFFFFEF8),
        border:         Color(0xFFEDD898),
        textPrimary:    Color(0xFF1A1200),
        textSecondary:  Color(0xFF6B4E00),
        textMuted:      Color(0xFFAA8C40),
        onPrimary:      Color(0xFFFFFFFF),
      ),
      dark: _ThemeSpec(
        primary:        Color(0xFF987010),
        primaryDark:    Color(0xFFAC8418),
        accent:         Color(0xFF887020),
        background:     Color(0xFF060500),
        surfaceOverlay: Color(0xFF090800),
        surface:        Color(0xFF0F0D00),
        surfaceRaised:  Color(0xFF191700),
        border:         Color(0xFF221E00),
        textPrimary:    Color(0xFFD8C888),
        textSecondary:  Color(0xFF5C4C18),
        textMuted:      Color(0xFF2E2808),
        onPrimary:      Color(0xFF060500),
      ),
    ),
  ];

  // ─── Style helpers ────────────────────────────────────────────────────────

  static AppColor lightStyle(int index) {
    final palette = themePalettes[normalizeThemeStyleIndex(index)];
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
          palette.light.primary.withOpacity(0.08),
          palette.light.primary.withOpacity(0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static AppColor darkStyle(int index) {
    final palette = themePalettes[normalizeThemeStyleIndex(index)];
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
          palette.dark.primary.withOpacity(0.15),
          palette.dark.primary.withOpacity(0.05),
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

  // ─── Fields ───────────────────────────────────────────────────────────────

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

  // ─── Context helpers ──────────────────────────────────────────────────────

  static AppColor fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static AppColor fromTheme(ThemeData theme) {
    final brightness = theme.brightness;
    final primary = theme.colorScheme.primary;
    final index = themePalettes.indexWhere((palette) {
      return brightness == Brightness.dark
          ? palette.dark.primary == primary
          : palette.light.primary == primary;
    });
    if (index == -1) return fromBrightness(brightness);
    return brightness == Brightness.dark ? darkStyle(index) : lightStyle(index);
  }

  static AppColor of(BuildContext context) => fromTheme(Theme.of(context));
}

// ─── Internal palette model ───────────────────────────────────────────────────

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