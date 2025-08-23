import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class AppAlert {
  /// Shows a reusable alert dialog
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    String confirmText = "OK",
    VoidCallback? onConfirm,
    String? cancelText,
    VoidCallback? onCancel,
  }) async {
    final colors = AppColor.of(context);

    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style:  TextStyle(fontWeight: FontWeight.bold, color: colors.textSecondary,),
          ),
          content: SingleChildScrollView(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
          ),
          actions: [
            if (cancelText != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onCancel?.call();
                },
                child: Text(cancelText,
                    style: TextStyle(color: colors.error)),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm?.call();
              },
              child: Text(confirmText,
                  style: TextStyle(color: colors.primary)),
            ),
          ],
        );
      },
    );
  }
}
