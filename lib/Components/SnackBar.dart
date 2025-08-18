import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

enum SnackBarType { success, error, warning }

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.error,
    }) {
  final colors = AppColor.of(context);

  Color bgColor;
  Color iconColor = colors.surface;
  IconData iconData;

  switch (type) {
    case SnackBarType.success:
      bgColor = colors.primary;
      iconData = Icons.check_circle_rounded;
      break;
    case SnackBarType.warning:
      bgColor = colors.warning;
      iconData = Icons.warning_amber_rounded;
      break;
    case SnackBarType.error:
    bgColor = colors.error;
      iconData = Icons.error_rounded;
      break;
  }

  // Create Overlay entry
  final overlay = OverlayEntry(
    builder: (context) => Positioned(
      top: 100, // distance from top
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSlide(
          offset: const Offset(0, -1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(iconData, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // Insert into overlay
  Overlay.of(context).insert(overlay);

  // Auto dismiss after 3s
  Future.delayed(const Duration(seconds: 3), () {
    overlay.remove();
  });
}
