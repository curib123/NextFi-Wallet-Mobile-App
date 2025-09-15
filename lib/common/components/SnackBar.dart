// lib/common/components/SnackBar.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      // --- New polish (all optional, safe defaults) ---
      bool useBlur = false,            // frosted glass look (subtle)
      bool showClose = true,           // top-right ✕ button
      bool showProgress = true,        // life-bar at the bottom
      double maxWidth = 720,           // responsive cap
    }) {
  final colors = AppColor.of(context);
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  Color bgColor;
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
      bgColor = colors.primary;
      iconData = Icons.info_rounded;
      break;
  }

  if (backgroundColor != null) bgColor = backgroundColor;
  if (icon != null) iconData = icon;

  // Choose a readable foreground automatically
  final fgColor = _autoOnColor(bgColor, isDark: isDark);

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
      // new
      useBlur: useBlur,
      showClose: showClose,
      showProgress: showProgress,
      maxWidth: maxWidth,
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  _currentSnackBarEntry = entry;

  // tiny haptic for feedback
  HapticFeedback.lightImpact();
}

Color _autoOnColor(Color bg, {required bool isDark}) {
  final lum = bg.computeLuminance(); // 0=dark, 1=light
  // Prefer white on darker backgrounds, dark grey on bright ones
  return lum < 0.45 ? Colors.white : Colors.black87;
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
    // new
    this.useBlur = false,
    this.showClose = true,
    this.showProgress = true,
    this.maxWidth = 720,
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

  // new
  final bool useBlur;
  final bool showClose;
  final bool showProgress;
  final double maxWidth;

  @override
  State<_FloatingSnackBarWidget> createState() => _FloatingSnackBarWidgetState();
}

class _FloatingSnackBarWidgetState extends State<_FloatingSnackBarWidget>
    with TickerProviderStateMixin {
  late final AnimationController _inOutCtrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _fade;
  late final AnimationController _lifeCtrl; // for progress bar

  @override
  void initState() {
    super.initState();

    _inOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final from = widget.position == SnackBarPosition.top
        ? const Offset(0, -0.18)
        : const Offset(0, 0.18);

    _offset = Tween<Offset>(begin: from, end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_inOutCtrl);

    _fade = CurvedAnimation(parent: _inOutCtrl, curve: Curves.easeOut);

    _lifeCtrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();

    _inOutCtrl.forward();

    // Auto dismiss: animate out, then remove
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _inOutCtrl.reverse();
      if (mounted) widget.onClosed();
    });
  }

  @override
  void dispose() {
    _lifeCtrl.dispose();
    _inOutCtrl.dispose();
    super.dispose();
  }

  EdgeInsets get _edgeInsets {
    final media = MediaQuery.of(context);
    final horizontal = 16.0;
    final topPad = media.viewPadding.top + 12.0;
    // If keyboard is up, respect viewInsets at the bottom
    final botSystem = media.viewPadding.bottom;
    final botInsets = media.viewInsets.bottom;
    final bottomPad = (botInsets > 0 ? botInsets : botSystem) + 12.0;

    return widget.position == SnackBarPosition.top
        ? EdgeInsets.fromLTRB(horizontal, topPad, horizontal, 0)
        : EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottomPad);
  }

  @override
  Widget build(BuildContext context) {
    final body = Material(
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
              child: _contentCard(context),
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
          child: body,
        ),
      ),
    );
  }

  Widget _contentCard(BuildContext context) {
    final bg = widget.bgColor;
    final fg = widget.fgColor;

    final card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: Semantics(
        liveRegion: true,
        label: 'Notification',
        child: Dismissible(
          key: const ValueKey('floating_snackbar'),
          direction: widget.dismissible
              ? (widget.position == SnackBarPosition.top
              ? DismissDirection.up
              : DismissDirection.down)
              : DismissDirection.none,
          onDismissed: (_) => widget.onClosed(),
          child: _Surface(
            blur: widget.useBlur ? 14 : 0,
            radius: 18,
            clip: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Subtle gradient for depth
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _tint(bg, 0.0),
                    _tint(bg, 0.06),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildRow(context, fg),
            ),
          ),
        ),
      ),
    );

    return card;
  }

  Widget _buildRow(BuildContext context, Color fg) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leading icon in a soft container
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: fg.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(widget.iconData, color: fg, size: 20),
              ),
              const SizedBox(width: 10),
              // Text
              Flexible(
                child: Text(
                  widget.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),

              // Action button (if any)
              if (widget.actionLabel != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    widget.onAction?.call();
                    widget.onClosed();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: fg.withOpacity(0.5), width: 1),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(widget.actionLabel!),
                ),
              ],

              // Close (optional)
              if (widget.showClose) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  splashRadius: 18,
                  color: fg,
                  onPressed: widget.onClosed,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ),

        // Life-bar (optional)
        if (widget.showProgress)
          AnimatedBuilder(
            animation: _lifeCtrl,
            builder: (context, _) {
              final t = 1 - _lifeCtrl.value; // 1→0 over time
              return Align(
                alignment: Alignment.bottomLeft,
                child: FractionallySizedBox(
                  widthFactor: t.clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.fgColor.withOpacity(0.85),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Slightly tinted variants for gradient
  Color _tint(Color c, double deltaLightness) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + deltaLightness).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor().withOpacity(0.98);
  }
}

/// A rounded surface with optional backdrop blur.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.blur = 0,
    this.radius = 16,
    this.clip = false,
  });

  final Widget child;
  final double blur;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(radius);

    final wrapped = ClipRRect(
      borderRadius: BorderRadius.all(r),
      child: blur > 0
          ? BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      )
          : child,
    );

    if (clip) return wrapped;

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.all(r)),
      child: wrapped,
    );
  }
}
