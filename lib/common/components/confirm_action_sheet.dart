import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// Reusable confirmation bottom sheet.
/// Returns true when user confirms; false/null when cancelled.
Future<bool> showConfirmActionSheet(
    BuildContext context, {
      required String title,
      required String message,
      String confirmLabel = 'Confirm',
      String cancelLabel = 'Cancel',
      IconData icon = LucideIcons.helpCircle,
      bool destructive = false,
    }) async {
  final colors = AppColor.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (destructive ? colors.warning : colors.info).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (destructive ? colors.warning : colors.info).withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: destructive ? colors.warning : colors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(color: colors.textSecondary, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructive ? colors.warning : colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}
