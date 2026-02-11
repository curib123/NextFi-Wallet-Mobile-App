import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

enum SnackBarType { info, success, warning, error }
enum SnackBarPosition { bottom, top }

/// Keep a single top toast at a time.
OverlayEntry? _currentTopSnack;

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.info,
      SnackBarPosition position = SnackBarPosition.top,
      Duration duration = const Duration(milliseconds: 2500),
      String? actionLabel,
      VoidCallback? onAction,
      VoidCallback? onTap,
      bool haptics = true,
      String? semanticsLabel,
    }) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();

  final colors = AppColor.of(context);
  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final bottomSafe = (mq.viewInsets.bottom > 0
      ? mq.viewInsets.bottom
      : mq.viewPadding.bottom);
  final topSafe = mq.viewPadding.top;

  final (bg, fg, icon) = _getTypeStyles(colors, type);

  /// Haptics
  if (haptics) {
    switch (type) {
      case SnackBarType.success:
        HapticFeedback.mediumImpact();
        break;
      case SnackBarType.warning:
        HapticFeedback.selectionClick();
        break;
      case SnackBarType.error:
        HapticFeedback.heavyImpact();
        break;
      case SnackBarType.info:
        HapticFeedback.lightImpact();
        break;
    }
  }

  /// TOP TOAST
  if (position == SnackBarPosition.top) {
    _showTopOverlayToast(
      context,
      top: topSafe + 16,
      left: 16,
      right: 16,
      colors: colors,
      bg: bg,
      fg: fg,
      icon: icon,
      message: message,
      textStyle: theme.textTheme.bodyMedium,
      duration: duration,
      type: type,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    );
    return;
  }

  /// BOTTOM SNACK
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomSafe),
      elevation: 0,
      padding: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      backgroundColor: Colors.transparent,
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      content: _SnackContent(
        colors: colors,
        bg: bg,
        fg: fg,
        icon: icon,
        message: message,
        textStyle: theme.textTheme.bodyMedium,
        actionLabel: actionLabel,
        onAction: onAction,
        semanticsLabel: semanticsLabel,
        type: type,
      ),
    ),
  );
}

(Color, Color, IconData) _getTypeStyles(
    AppColor colors, SnackBarType type) {
  return switch (type) {
    SnackBarType.success => (
    colors.success,
    Colors.white,
    LucideIcons.checkCircle2,
    ),
    SnackBarType.warning => (
    colors.warning,
    Colors.white,
    LucideIcons.alertTriangle,
    ),
    SnackBarType.error => (
    colors.error,
    Colors.white,
    LucideIcons.xCircle,
    ),
    SnackBarType.info => (
    colors.primary,
    Colors.white,
    LucideIcons.info,
    ),
  };
}

/// ─────────────────────────────────────────
/// CONTENT (BOTTOM + TOP SHARED UI)
/// ─────────────────────────────────────────
class _SnackContent extends StatelessWidget {
  const _SnackContent({
    required this.colors,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.message,
    required this.textStyle,
    required this.type,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  final AppColor colors;
  final Color bg, fg;
  final IconData icon;
  final String message;
  final TextStyle? textStyle;
  final SnackBarType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,

        borderRadius: BorderRadius.circular(14),

        /// Soft fintech shadow (NOT glow)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],

        /// Subtle border
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// Icon chip
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: fg),
          ),

          const SizedBox(width: 12),

          /// Message
          Expanded(
            child: Semantics(
              label: semanticsLabel,
              child: Text(
                message,
                style: (textStyle ?? const TextStyle())
                    .copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          /// Action
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                backgroundColor:
                Colors.black.withOpacity(0.12),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize:
                MaterialTapTargetSize
                    .shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: fg,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────
/// TOP OVERLAY
/// ─────────────────────────────────────────
void _showTopOverlayToast(
    BuildContext context, {
      required double top,
      required double left,
      required double right,
      required AppColor colors,
      required Color bg,
      required Color fg,
      required IconData icon,
      required String message,
      required TextStyle? textStyle,
      required Duration duration,
      required SnackBarType type,
      VoidCallback? onTap,
      String? actionLabel,
      VoidCallback? onAction,
      String? semanticsLabel,
    }) {
  final overlay =
  Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _currentTopSnack?.remove();
  _currentTopSnack = null;

  final entry = OverlayEntry(
    builder: (ctx) => _TopSnackAnimated(
      top: top,
      left: left,
      right: right,
      colors: colors,
      bg: bg,
      fg: fg,
      icon: icon,
      message: message,
      textStyle: textStyle,
      duration: duration,
      type: type,
      onClose: () {
        _currentTopSnack?.remove();
        _currentTopSnack = null;
      },
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    ),
  );

  overlay.insert(entry);
  _currentTopSnack = entry;
}

/// ─────────────────────────────────────────
/// TOP ANIMATED WIDGET
/// ─────────────────────────────────────────
class _TopSnackAnimated extends StatefulWidget {
  const _TopSnackAnimated({
    required this.top,
    required this.left,
    required this.right,
    required this.colors,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.message,
    required this.textStyle,
    required this.duration,
    required this.type,
    required this.onClose,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  final double top, left, right;
  final AppColor colors;
  final Color bg, fg;
  final IconData icon;
  final String message;
  final TextStyle? textStyle;
  final Duration duration;
  final SnackBarType type;
  final VoidCallback onClose;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;

  @override
  State<_TopSnackAnimated> createState() =>
      _TopSnackAnimatedState();
}

class _TopSnackAnimatedState
    extends State<_TopSnackAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final Animation<double> _fade =
  CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide =
  Tween(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _ac.forward();
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
    const double maxCardWidth = 640;

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
            child: Dismissible(
              key: const ValueKey('top_snack'),
              direction:
              DismissDirection.horizontal,
              onDismissed: (_) =>
                  widget.onClose(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                  widget.onTap ?? _dismiss,
                  borderRadius:
                  BorderRadius.circular(
                      14),
                  child: Container(
                    constraints:
                    const BoxConstraints(
                      maxWidth:
                      maxCardWidth,
                    ),
                    decoration:
                    BoxDecoration(
                      color: widget.bg,
                      borderRadius:
                      BorderRadius
                          .circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(
                              0.15),
                          blurRadius: 16,
                          offset:
                          const Offset(
                              0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(
                            0.06),
                        width: 1,
                      ),
                    ),
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .black
                                .withOpacity(
                                0.12),
                            shape: BoxShape
                                .circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 18,
                            color:
                            widget.fg,
                          ),
                        ),
                        const SizedBox(
                            width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color:
                              widget.fg,
                              fontWeight:
                              FontWeight
                                  .w600,
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
          ),
        ),
      ),
    );
  }
}
