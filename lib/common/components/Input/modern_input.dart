// Replace your existing modernInput with this version
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

/// Modern, compact input decoration with useful sizing knobs.
/// Works well for single-line and multi-line (up to 5 lines) fields.
///
/// HOW TO SHOW UP TO 5 LINES:
/// TextFormField(
///   minLines: 1,
///   maxLines: 5,
///   decoration: modernInput(context, multiline: true),
/// )
InputDecoration modernInput(
    BuildContext context, {
      String? placeholder,                 // hint/placeholder only (no floating label)
      Widget? prefix,
      Widget? suffix,

      // Sizing knobs (defaults are compact)
      bool dense = true,
      EdgeInsetsGeometry? padding,         // default compact padding if null
      double hintFontSize = 12.0,
      double borderRadius = 12.0,

      // Multi-line tuning
      bool multiline = false,              // set to true when minLines/maxLines > 1
      double lineHeight = 10.0,            // vertical padding base per "line"
      // Optional: tighter icon constraints (helps save horizontal space)
      BoxConstraints? prefixConstraints,
      BoxConstraints? suffixConstraints,
    }) {
  final c = AppColor.of(context);
  final theme = Theme.of(context);

  // If multiline, slightly loosen density and add a bit more vertical padding so up to 5 lines look balanced.
  final bool isDense = multiline ? false : dense;
  final EdgeInsetsGeometry resolvedPadding =
      padding ??
          (multiline
              ? EdgeInsets.symmetric(horizontal: 12, vertical: lineHeight) // tuned for multi-line
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10)); // compact single-line

  return InputDecoration(
    isDense: isDense,
    alignLabelWithHint: multiline, // better vertical alignment for multi-line
    hintText: placeholder,
    hintStyle: TextStyle(
      fontSize: hintFontSize,
      color: c.textSecondary.withOpacity(0.90),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: c.primary.withOpacity(0.05),

    // Icons / affixes
    prefixIcon: prefix,
    suffixIcon: suffix,
    prefixIconConstraints: prefixConstraints ??
        const BoxConstraints(minWidth: 40, minHeight: 40),
    suffixIconConstraints: suffixConstraints ??
        const BoxConstraints(minWidth: 40, minHeight: 40),

    // Padding
    contentPadding: resolvedPadding,

    // Borders
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: c.primary.withOpacity(0.10),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: c.primary.withOpacity(0.35),
        width: 1.15,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide.none,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: theme.colorScheme.error.withOpacity(0.90),
        width: 1,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: theme.colorScheme.error,
        width: 1.15,
      ),
    ),

    // Helper/counter styles
    helperStyle: TextStyle(
      fontSize: 12,
      color: c.textSecondary,
      height: 1.2,
    ),
    counterStyle: TextStyle(
      fontSize: 11.5,
      color: c.textSecondary.withOpacity(0.9),
      height: 1.1,
    ),
    errorStyle: TextStyle(
      fontSize: 12,
      color: theme.colorScheme.error,
      height: 1.15,
    ),
  );
}
