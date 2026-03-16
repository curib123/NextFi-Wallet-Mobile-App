import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static const List<String> fallback = <String>[
    'Roboto',
    '.SF Pro Text',
    'Segoe UI',
    'Segoe UI Symbol',
    'Noto Sans',
    'Noto Sans Symbols',
    'Noto Sans Symbols2',
    'Arial Unicode MS',
    'Arial',
  ];

  static TextStyle inter({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.inter(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    ).copyWith(fontFamilyFallback: fallback);
  }

  static TextTheme interTextTheme([TextTheme? base]) {
    return GoogleFonts.interTextTheme(base).apply(fontFamilyFallback: fallback);
  }

  static TextStyle sora({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    return GoogleFonts.sora(
      textStyle: textStyle,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    ).copyWith(fontFamilyFallback: fallback);
  }

  static TextTheme soraTextTheme([TextTheme? base]) {
    return GoogleFonts.soraTextTheme(base).apply(fontFamilyFallback: fallback);
  }

  static TextStyle display({
    required Color color,
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return sora(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.08,
      letterSpacing: -0.8,
    );
  }

  static TextStyle headline({
    required Color color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return sora(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.14,
      letterSpacing: -0.45,
    );
  }

  static TextStyle title({
    required Color color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return sora(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.2,
      letterSpacing: -0.2,
    );
  }

  static TextStyle body({
    required Color color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.5,
      letterSpacing: -0.1,
    );
  }

  static TextStyle label({
    required Color color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0.1,
  }) {
    return inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.25,
      letterSpacing: letterSpacing,
    );
  }
}
