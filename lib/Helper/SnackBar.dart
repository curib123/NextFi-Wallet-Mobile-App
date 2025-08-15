import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

enum SnackBarType { success, error, warning }

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.error,
    }) {
  final colors = AppColor.of(context); // your app theme

  Color bgColor;
  Color textColor = colors.surface;

  switch (type) {
    case SnackBarType.success:
      bgColor = colors.success; // greenish
      break;
    case SnackBarType.warning:
      bgColor = colors.warning; // yellow/orange
      break;
    case SnackBarType.error:
    default:
      bgColor = colors.error; // reddish
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
      elevation: 6,
    ),
  );
}
