import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

      // New (optional) goodies:
      String? actionLabel,
      VoidCallback? onAction,
      VoidCallback? onTap,
      bool haptics = true,
      String? semanticsLabel,
    }) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars(); // clear bottom bars if any

  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final bottomSafe = (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.viewPadding.bottom);
  final topSafe = mq.viewPadding.top;

  final scheme = theme.colorScheme;

  final Color baseBg = switch (type) {
    SnackBarType.success => _blend(scheme.secondaryContainer, scheme.onSecondaryContainer, .06),
    SnackBarType.warning => _blend(const Color(0xFFFFF4E5), const Color(0xFF8A6D3B), .06),
    SnackBarType.error   => _blend(scheme.errorContainer, scheme.onErrorContainer, .08),
    SnackBarType.info    => _blend(scheme.surfaceVariant, scheme.onSurfaceVariant, .04),
  };
  final Color baseFg = switch (type) {
    SnackBarType.success => scheme.onSecondaryContainer,
    SnackBarType.warning => const Color(0xFF5F4B1A),
    SnackBarType.error   => scheme.onErrorContainer,
    SnackBarType.info    => scheme.onSurfaceVariant,
  };

  // Nudge contrast slightly in very light/dark modes
  final bool isDark = theme.brightness == Brightness.dark;
  final Color bg = isDark ? _blend(baseBg, Colors.black, .06) : _blend(baseBg, Colors.white, .06);
  final Color fg = baseFg;

  final IconData icon = switch (type) {
    SnackBarType.success => Icons.check_circle_rounded,
    SnackBarType.warning => Icons.warning_rounded,
    SnackBarType.error   => Icons.error_rounded,
    SnackBarType.info    => Icons.info_rounded,
  };

  // Gentle haptics
  if (haptics) {
    switch (type) {
      case SnackBarType.success:
        HapticFeedback.lightImpact();
        break;
      case SnackBarType.warning:
        HapticFeedback.selectionClick();
        break;
      case SnackBarType.error:
        HapticFeedback.mediumImpact();
        break;
      case SnackBarType.info:
      // no-op
        break;
    }
  }

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
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    );
    return;
  }

  // Bottom snack (native SnackBar) – keeps your original look
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
              semanticsLabel: semanticsLabel,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: fg),
              child: Text(actionLabel),
            ),
          ],
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
      VoidCallback? onTap,
      String? actionLabel,
      VoidCallback? onAction,
      String? semanticsLabel,
    }) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // Remove any existing top toast
  _currentTopSnack?..remove();
  _currentTopSnack = null;

  final entry = OverlayEntry(
    builder: (ctx) => _TopSnackAnimated(
      top: top,
      left: left,
      right: right,
      bg: bg,
      fg: fg,
      icon: icon,
      message: message,
      textStyle: textStyle,
      duration: duration,
      onTap: onTap,
      onClose: () {
        _currentTopSnack?..remove();
        _currentTopSnack = null;
      },
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    ),
  );

  overlay.insert(entry);
  _currentTopSnack = entry;
}

/// Animated container for the top toast
class _TopSnackAnimated extends StatefulWidget {
  const _TopSnackAnimated({
    required this.top,
    required this.left,
    required this.right,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.message,
    required this.textStyle,
    required this.duration,
    required this.onClose,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  final double top, left, right;
  final Color bg, fg;
  final IconData icon;
  final String message;
  final TextStyle? textStyle;
  final Duration duration;
  final VoidCallback onClose;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;

  @override
  State<_TopSnackAnimated> createState() => _TopSnackAnimatedState();
}

class _TopSnackAnimatedState extends State<_TopSnackAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide =
  Tween(begin: const Offset(0, -0.12), end: Offset.zero).animate(_fade);

  @override
  void initState() {
    super.initState();
    _ac.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ac.reverse();
    if (mounted) widget.onClose();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make wide layouts look nice by capping max width
    const double maxCardWidth = 640;

    final card = Dismissible(
      key: const ValueKey('top_snack'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => widget.onClose(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap ?? _dismiss,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: maxCardWidth),
            decoration: BoxDecoration(
              color: widget.bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                  color: Color(0x33000000),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: widget.fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: widget.semanticsLabel,
                    child: Text(
                      widget.message,
                      style: (widget.textStyle ?? const TextStyle()).copyWith(color: widget.fg),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ),
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      widget.onAction!.call();
                      _dismiss();
                    },
                    style: TextButton.styleFrom(foregroundColor: widget.fg),
                    child: Text(widget.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      child: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: card,
          ),
        ),
      ),
    );
  }
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
