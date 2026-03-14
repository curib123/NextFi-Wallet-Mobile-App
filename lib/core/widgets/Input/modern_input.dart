import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

/// Minimalist modern input decoration with clean aesthetics.
/// Supports single-line and multi-line fields elegantly.
///
/// Usage:
/// TextFormField(
///   decoration: modernInput(context, placeholder: 'Enter amount'),
/// )
///
/// Multi-line:
/// TextFormField(
///   minLines: 1,
///   maxLines: 5,
///   decoration: modernInput(context, multiline: true),
/// )
InputDecoration modernInput(
    BuildContext context, {
      String? placeholder,
      Widget? prefix,
      Widget? suffix,
      bool multiline = false,
      double borderRadius = 12.0,
    }) {
  final c = AppColor.of(context);
  final theme = Theme.of(context);

  return InputDecoration(
    hintText: placeholder,
    hintStyle: TextStyle(
      fontSize: 14,
      color: c.textSecondary.withValues(alpha: 0.6),
      fontWeight: FontWeight.w400,
    ),
    filled: true,
    fillColor: c.surface,
    prefixIcon: prefix,
    suffixIcon: suffix,
    contentPadding: multiline
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: c.border.withValues(alpha: 0.3),
        width: 1,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: c.border.withValues(alpha: 0.3),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: c.primary.withValues(alpha: 0.5),
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: theme.colorScheme.error.withValues(alpha: 0.6),
        width: 1,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: theme.colorScheme.error,
        width: 1.5,
      ),
    ),
    errorStyle: TextStyle(
      fontSize: 12,
      color: theme.colorScheme.error,
      height: 1.3,
    ),
  );
}
