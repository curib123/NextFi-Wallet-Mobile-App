import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';

enum ButtonType { filled, outlined, disabled }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.filled,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    final bool isDisabled = type == ButtonType.disabled;

    Color fgColor;
    Color? bgColor;
    Color borderColor;

    switch (type) {
      case ButtonType.filled:
        fgColor = colors.onPrimary;
        bgColor = colors.primary;
        borderColor = colors.primary;
        break;
      case ButtonType.outlined:
        fgColor = colors.textPrimary;
        bgColor = colors.surface;
        borderColor = colors.border;
        break;
      case ButtonType.disabled:
        fgColor = colors.textMuted;
        bgColor = colors.surfaceRaised;
        borderColor = colors.border;
        break;
    }

    final iconWidget = icon == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(icon, size: 18, color: fgColor),
          );

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) iconWidget,
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ),
      ],
    );

    final Size minSize = const Size(0, 40);
    final EdgeInsets padding = const EdgeInsets.symmetric(
      vertical: 13,
      horizontal: 14,
    );
    final BorderRadius radius = BorderRadius.circular(10);

    Widget button;
    if (type == ButtonType.filled) {
      final style = ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceRaised;
          }
          return bgColor!;
        }),
        foregroundColor: WidgetStatePropertyAll(fgColor),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.surface;
          return colors.onPrimary.withValues(alpha: 0.08);
        }),
        padding: WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: WidgetStatePropertyAll(minSize),
      );

      button = AppButton(
        variant: AppButtonVariant.elevated,
        style: style,
        onPressed: isDisabled ? null : onPressed,
        child: child,
      );
    } else {
      final style = ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (type == ButtonType.disabled) return bgColor!;
          return colors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textMuted;
          }
          return fgColor;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.surface;
          return colors.primary.withValues(alpha: 0.08);
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: borderColor, width: 1.3);
          }
          return BorderSide(
            color: type == ButtonType.outlined ? borderColor : colors.surface,
            width: 1.3,
          );
        }),
        padding: WidgetStatePropertyAll(padding),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
        minimumSize: WidgetStatePropertyAll(minSize),
      );

      button = AppButton(
        variant: AppButtonVariant.outlined,
        style: style,
        onPressed: isDisabled ? null : onPressed,
        child: child,
      );
    }

    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}
