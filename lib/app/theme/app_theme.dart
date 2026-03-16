import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';

class AppTheme {
  static ThemeData light() => _build(AppColor.light, Brightness.light);

  static ThemeData dark() => _build(AppColor.dark, Brightness.dark);

  static ThemeData _build(AppColor colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          secondary: colors.primary,
          onSecondary: colors.onPrimary,
          tertiary: colors.warning,
          onTertiary: colors.onPrimary,
          error: colors.error,
          onError: Colors.white,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          surfaceContainerLowest: colors.background,
          surfaceContainerLow: colors.surfaceOverlay,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.surfaceRaised,
          surfaceContainerHighest: colors.surfaceRaised,
          outline: colors.border,
          outlineVariant: colors.border,
          shadow: isDark ? Colors.black : const Color(0xFF111111),
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
          inverseSurface: colors.textPrimary,
          onInverseSurface: colors.background,
          inversePrimary: colors.primary,
        );

    final baseText = AppFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark(useMaterial3: true).textTheme
          : ThemeData.light(useMaterial3: true).textTheme,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    final textTheme = baseText.copyWith(
      displayLarge: AppFonts.display(
        color: colors.textPrimary,
        fontSize: 40,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: AppFonts.display(
        color: colors.textPrimary,
        fontSize: 34,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: AppFonts.display(
        color: colors.textPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: AppFonts.headline(
        color: colors.textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: AppFonts.headline(
        color: colors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: AppFonts.headline(
        color: colors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: AppFonts.title(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: AppFonts.title(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: AppFonts.label(
        color: colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
      ),
      bodyLarge: AppFonts.body(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: AppFonts.body(
        color: colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: AppFonts.body(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: AppFonts.label(
        color: colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
      ),
      labelMedium: AppFonts.label(
        color: colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: AppFonts.label(
        color: colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.18,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      cardColor: colors.surface,
      dividerColor: colors.border,
      disabledColor: colors.textMuted,
      shadowColor: (isDark ? Colors.black : colors.textPrimary).withValues(
        alpha: isDark ? 0.32 : 0.08,
      ),
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: (isDark ? Colors.black : colors.textPrimary).withValues(
          alpha: isDark ? 0.22 : 0.08,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.64 : 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
          height: 1.45,
        ),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        space: 1,
        thickness: 1,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        tileColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: colors.primary.withValues(alpha: isDark ? 0.14 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primary : colors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.primary : colors.textSecondary,
            height: 1.1,
            letterSpacing: 0.08,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceRaised,
        disabledColor: colors.surfaceOverlay,
        selectedColor: colors.primary.withValues(alpha: isDark ? 0.14 : 0.12),
        secondarySelectedColor: colors.primary.withValues(
          alpha: isDark ? 0.14 : 0.12,
        ),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          height: 1.2,
        ),
        secondaryLabelStyle: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.primary,
          height: 1.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceRaised,
        hintStyle: AppFonts.inter(
          fontSize: 14,
          color: colors.textSecondary.withValues(alpha: isDark ? 0.8 : 0.9),
          height: 1.45,
        ),
        labelStyle: AppFonts.inter(
          fontSize: 14,
          color: colors.textSecondary,
          height: 1.35,
        ),
        floatingLabelStyle: AppFonts.inter(
          fontSize: 14,
          color: colors.primary,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.7)),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 1),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 1.4),
        ),
        errorStyle: AppFonts.inter(
          fontSize: 12,
          color: colors.error,
          height: 1.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: isDark ? 0 : 1,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 52),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceRaised,
          disabledForegroundColor: colors.textMuted,
          textStyle: AppFonts.label(
            color: colors.onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceRaised,
          disabledForegroundColor: colors.textMuted,
          textStyle: AppFonts.label(
            color: colors.onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          backgroundColor: colors.surface,
          disabledForegroundColor: colors.textMuted,
          textStyle: AppFonts.label(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor: colors.textMuted,
          textStyle: AppFonts.label(
            color: colors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: colors.border, width: 1.2),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surfaceRaised;
        }),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary.withValues(alpha: 0.35);
          }
          return colors.border;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.border,
        circularTrackColor: colors.border,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        dividerColor: colors.border,
      ),
    );
  }
}
