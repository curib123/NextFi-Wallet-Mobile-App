import 'package:flutter/material.dart';

enum SnackBarType { info, success, warning, error }
enum SnackBarPosition { bottom, top }

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.info,
      SnackBarPosition position = SnackBarPosition.bottom,
      Duration duration = const Duration(milliseconds: 2200),
    }) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // Clear any current bar to avoid stacking tall snackbars on open
  messenger.clearSnackBars();

  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);

  // If keyboard is open, use viewInsets; otherwise, use safe area padding.
  final bottomSafe =
  (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.viewPadding.bottom);
  final topSafe = mq.viewPadding.top;

  final isTop = position == SnackBarPosition.top;

  final EdgeInsets margin = isTop
      ? EdgeInsets.fromLTRB(16, topSafe + 16, 16, 0)
      : EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomSafe);

  final Color bg = switch (type) {
    SnackBarType.success => _blend(theme.colorScheme.secondaryContainer, theme.colorScheme.onSecondaryContainer, .06),
    SnackBarType.warning => _blend(const Color(0xFFFFF4E5), const Color(0xFF8A6D3B), .06),
    SnackBarType.error   => _blend(theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer, .08),
    SnackBarType.info    => _blend(theme.colorScheme.surfaceVariant, theme.colorScheme.onSurfaceVariant, .04),
  };

  final Color fg = switch (type) {
    SnackBarType.success => theme.colorScheme.onSecondaryContainer,
    SnackBarType.warning => const Color(0xFF5F4B1A),
    SnackBarType.error   => theme.colorScheme.onErrorContainer,
    SnackBarType.info    => theme.colorScheme.onSurfaceVariant,
  };

  final IconData icon = switch (type) {
    SnackBarType.success => Icons.check_circle_rounded,
    SnackBarType.warning => Icons.warning_rounded,
    SnackBarType.error   => Icons.error_rounded,
    SnackBarType.info    => Icons.info_rounded,
  };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: margin,
      elevation: 2,
      // keep it compact so it never “covers” too much on open
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: bg,
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
              maxLines: 3,                        // cap height on long messages
              overflow: TextOverflow.ellipsis,    // avoid tall bars
              softWrap: true,
            ),
          ),
        ],
      ),
    ),
  );
}

/// tiny utility to keep colors subtle
Color _blend(Color a, Color b, double t) {
  return Color.fromARGB(
    (a.alpha * (1 - t) + b.alpha * t).round(),
    (a.red   * (1 - t) + b.red   * t).round(),
    (a.green * (1 - t) + b.green * t).round(),
    (a.blue  * (1 - t) + b.blue  * t).round(),
  );
}
