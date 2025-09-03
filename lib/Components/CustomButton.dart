import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

enum ButtonType { filled, outlined }

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

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18, // smaller icon
            color: type == ButtonType.filled ? Colors.white : colors.primary,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 14, // slimmer font size
            fontWeight: FontWeight.w600,
            color: type == ButtonType.filled ? Colors.white : colors.primary,
          ),
        ),
      ],
    );

    if (type == ButtonType.filled) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), // slimmer padding
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
            minimumSize: const Size(0, 36), // ensures slim height
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
    } else {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary, width: 1.3),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), // slimmer padding
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(0, 36),
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
    }
  }
}
