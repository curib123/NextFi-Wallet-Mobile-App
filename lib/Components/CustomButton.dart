import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

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

    // Resolve colors per type
    Color fgColor;
    Color? bgColor; // only used for filled
    Color borderColor;

    switch (type) {
      case ButtonType.filled:
        fgColor = Colors.white;
        bgColor = colors.primary;
        borderColor = Colors.transparent;
        break;
      case ButtonType.outlined:
        fgColor = colors.primary;
        bgColor = Colors.transparent;
        borderColor = colors.primary;
        break;
      case ButtonType.disabled:
        fgColor = colors.textSecondary.withOpacity(0.75);
        bgColor = colors.background; // subtle filled look
        borderColor = colors.border.withOpacity(0.6);
        break;
    }

    final iconWidget = icon == null
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Icon(
        icon,
        size: 18,
        color: fgColor,
      ),
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

    final Size minSize = const Size(0, 36);
    final EdgeInsets padding =
    const EdgeInsets.symmetric(vertical: 10, horizontal: 14);
    final BorderRadius radius = BorderRadius.circular(10);

    // Choose the underlying button widget based on type.
    // Disabled uses OutlinedButton semantics with custom colors and onPressed: null.
    Widget button;
    if (type == ButtonType.filled) {
      final style = ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return colors.primary.withOpacity(0.45);
          }
          return bgColor!;
        }),
        foregroundColor: MaterialStatePropertyAll(fgColor),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) return Colors.transparent;
          return Colors.white.withOpacity(0.08);
        }),
        padding: MaterialStatePropertyAll(padding),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
        elevation: MaterialStatePropertyAll(
          Theme.of(context).brightness == Brightness.light ? 1 : 0,
        ),
        minimumSize: MaterialStatePropertyAll(minSize),
      );

      button = ElevatedButton(
        style: style,
        onPressed: isDisabled ? null : onPressed,
        child: child,
      );
    } else {
      // outlined & disabled share the same base (OutlinedButton) with custom side/background
      final style = ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (type == ButtonType.disabled) return bgColor!;
          return Colors.transparent;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return colors.textSecondary.withOpacity(0.75);
          }
          return fgColor;
        }),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) return Colors.transparent;
          return colors.primary.withOpacity(0.06);
        }),
        side: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return BorderSide(color: borderColor, width: 1.3);
          }
          return BorderSide(
            color: type == ButtonType.outlined ? borderColor : Colors.transparent,
            width: 1.3,
          );
        }),
        padding: MaterialStatePropertyAll(padding),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius),
        ),
        minimumSize: MaterialStatePropertyAll(minSize),
      );

      button = OutlinedButton(
        style: style,
        onPressed: isDisabled ? null : onPressed,
        child: child,
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: button,
    );
  }
}
