import 'package:flutter/material.dart';

enum SnackBarType { info, success, warning, error }
enum SnackBarPosition { bottom, top }

// Keep a single top toast at a time.
OverlayEntry? _currentTopSnack;

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.info,
      SnackBarPosition position = SnackBarPosition.top, // default TOP
      Duration duration = const Duration(milliseconds: 2200),
    }) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars(); // clear bottom bars if any

  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final bottomSafe = (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.viewPadding.bottom);
  final topSafe = mq.viewPadding.top;

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

  if (position == SnackBarPosition.top) {
    _showTopOverlayToast(
      context,
      top: topSafe + 16,
      left: 16,
      right: 16,
      bg: bg,
      fg: fg,
      icon: icon,
      message: message,
      textStyle: theme.textTheme.bodyMedium,
      duration: duration,
    );
    return;
  }

  // Bottom snack (native SnackBar)
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomSafe),
      elevation: 2,
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
              style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: fg),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showTopOverlayToast(
    BuildContext context, {
      required double top,
      required double left,
      required double right,
      required Color bg,
      required Color fg,
      required IconData icon,
      required String message,
      required TextStyle? textStyle,
      required Duration duration,
    }) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // Remove any existing top toast
  _currentTopSnack?..remove();
  _currentTopSnack = null;

  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: top,
      left: left,
      right: right,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            _currentTopSnack?..remove();
            _currentTopSnack = null;
          },
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 0, offset: Offset(0, 2), color: Color(0x33000000))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: (textStyle ?? const TextStyle()).copyWith(color: fg),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  _currentTopSnack = entry;

  Future.delayed(duration, () {
    _currentTopSnack?..remove();
    _currentTopSnack = null;
  });
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
