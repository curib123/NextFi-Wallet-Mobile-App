import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

enum SnackBarType { success, error, warning, info }
enum SnackBarPosition { top, bottom }

// Keep only one overlay at a time
OverlayEntry? _currentSnackBarEntry;

void showFloatingSnackBar(
    BuildContext context, {
      required String message,
      SnackBarType type = SnackBarType.error,
      SnackBarPosition position = SnackBarPosition.top,
      Duration duration = const Duration(seconds: 3),
      String? actionLabel,
      VoidCallback? onAction,
      bool dismissible = true,
      IconData? icon,          // optional: override icon
      Color? backgroundColor,  // optional: override background
    }) {
  final colors = AppColor.of(context);

  Color bgColor;
  Color fgColor = colors.surface; // text & icon color
  IconData iconData;

  switch (type) {
    case SnackBarType.success:
      bgColor = colors.success;
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
    case SnackBarType.info:
    // Use brand color for informational notices
      bgColor = colors.primary;
      iconData = Icons.info_rounded;
      break;
  }

  if (backgroundColor != null) bgColor = backgroundColor;
  if (icon != null) iconData = icon;

  // Remove any existing snackbar first
  _currentSnackBarEntry?.remove();
  _currentSnackBarEntry = null;

  final entry = OverlayEntry(
    builder: (context) => _FloatingSnackBarWidget(
      message: message,
      bgColor: bgColor,
      fgColor: fgColor,
      iconData: iconData,
      duration: duration,
      position: position,
      actionLabel: actionLabel,
      onAction: onAction,
      dismissible: dismissible,
      onClosed: () {
        _currentSnackBarEntry?.remove();
        _currentSnackBarEntry = null;
      },
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  _currentSnackBarEntry = entry;
}

class _FloatingSnackBarWidget extends StatefulWidget {
  const _FloatingSnackBarWidget({
    required this.message,
    required this.bgColor,
    required this.fgColor,
    required this.iconData,
    required this.duration,
    required this.position,
    required this.dismissible,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color bgColor;
  final Color fgColor;
  final IconData iconData;
  final Duration duration;
  final SnackBarPosition position;
  final bool dismissible;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClosed;

  @override
  State<_FloatingSnackBarWidget> createState() => _FloatingSnackBarWidgetState();
}

class _FloatingSnackBarWidgetState extends State<_FloatingSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final from = widget.position == SnackBarPosition.top
        ? const Offset(0, -0.2)
        : const Offset(0, 0.2);

    _offset = Tween<Offset>(begin: from, end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_controller);

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    // Auto dismiss: animate out, then remove
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  EdgeInsets get _edgeInsets {
    final media = MediaQuery.of(context);
    final hor = 20.0;
    final topPad = media.viewPadding.top + 12.0;
    final botPad = media.viewPadding.bottom + 12.0;

    return widget.position == SnackBarPosition.top
        ? EdgeInsets.fromLTRB(hor, topPad, hor, 0)
        : EdgeInsets.fromLTRB(hor, 0, hor, botPad);
  }

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: SafeArea(
        top: widget.position == SnackBarPosition.top,
        bottom: widget.position == SnackBarPosition.bottom,
        child: Padding(
          padding: _edgeInsets,
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _fade,
              child: _buildBody(context),
            ),
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: widget.position == SnackBarPosition.top
              ? Alignment.topCenter
              : Alignment.bottomCenter,
          child: content,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Dismissible(
      key: const ValueKey('floating_snackbar'),
      direction: widget.dismissible
          ? (widget.position == SnackBarPosition.top
          ? DismissDirection.up
          : DismissDirection.down)
          : DismissDirection.none,
      onDismissed: (_) => widget.onClosed(),
      child: GestureDetector(
        onTap: () {
          if (widget.onAction != null) {
            widget.onAction!.call();
          } else if (widget.dismissible) {
            widget.onClosed();
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.iconData, color: widget.fgColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.fgColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
              if (widget.actionLabel != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.fgColor,
                  ),
                  child: Text(
                    widget.actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
