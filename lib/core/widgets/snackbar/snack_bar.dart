import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';

enum SnackBarType { info, success, warning, error }

enum SnackBarPosition { bottom, top }

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
  final trimmedMessage = message.trim();
  if (trimmedMessage.isEmpty) return;
  if (!context.mounted) return;

  final colors = AppColor.of(context);
  final theme = Theme.of(context);
  final mq = MediaQuery.of(context);
  final bottomSafe = mq.viewInsets.bottom > 0
      ? mq.viewInsets.bottom
      : mq.viewPadding.bottom;
  final topSafe = mq.viewPadding.top;

  final palette = _getTypeStyles(colors, type);

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

  if (position == SnackBarPosition.top) {
    _removeCurrentTopSnack();
    final didShowOverlay = _showTopOverlayToast(
      context,
      top: topSafe + 12,
      left: 16,
      right: 16,
      colors: colors,
      palette: palette,
      message: trimmedMessage,
      textStyle: theme.textTheme.bodyMedium,
      duration: duration,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    );
    if (didShowOverlay) return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  _removeCurrentTopSnack();
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomSafe),
      elevation: 0,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      content: _SnackSurface(
        colors: colors,
        palette: palette,
        message: trimmedMessage,
        textStyle: theme.textTheme.bodyMedium,
        actionLabel: actionLabel,
        onAction: onAction,
        semanticsLabel: semanticsLabel,
        compact: false,
      ),
    ),
  );
}

_SnackPalette _getTypeStyles(AppColor colors, SnackBarType type) {
  return switch (type) {
    SnackBarType.success => _SnackPalette(
      accent: colors.success,
      foreground: colors.onPrimary,
      icon: LucideIcons.checkCircle2,
      accentSoft: colors.success.withValues(alpha: 0.2),
    ),
    SnackBarType.warning => _SnackPalette(
      accent: colors.warning,
      foreground: colors.onPrimary,
      icon: LucideIcons.alertTriangle,
      accentSoft: colors.warning.withValues(alpha: 0.24),
    ),
    SnackBarType.error => _SnackPalette(
      accent: colors.error,
      foreground: colors.onPrimary,
      icon: LucideIcons.xCircle,
      accentSoft: colors.error.withValues(alpha: 0.22),
    ),
    SnackBarType.info => _SnackPalette(
      accent: colors.primary,
      foreground: colors.onPrimary,
      icon: LucideIcons.info,
      accentSoft: colors.primary.withValues(alpha: 0.2),
    ),
  };
}

class _SnackPalette {
  const _SnackPalette({
    required this.accent,
    required this.foreground,
    required this.icon,
    required this.accentSoft,
  });

  final Color accent;
  final Color foreground;
  final IconData icon;
  final Color accentSoft;
}

class _SnackSurface extends StatelessWidget {
  const _SnackSurface({
    required this.colors,
    required this.palette,
    required this.message,
    required this.textStyle,
    required this.semanticsLabel,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.contentOpacity = 1,
    this.iconOpacity = 1,
  });

  final AppColor colors;
  final _SnackPalette palette;
  final String message;
  final TextStyle? textStyle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? semanticsLabel;
  final bool compact;
  final double contentOpacity;
  final double iconOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 20.0 : 22.0;
    final horizontal = compact ? 14.0 : 16.0;
    final vertical = compact ? 12.0 : 14.0;
    final actionAvailable = actionLabel != null && onAction != null;
    final messageWidget = Opacity(
      opacity: contentOpacity,
      child: Semantics(
        label: semanticsLabel,
        child: Text(
          message,
          maxLines: actionAvailable ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.body(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ).merge(textStyle).copyWith(color: colors.textPrimary, height: 1.2),
        ),
      ),
    );
    final actionWidget = actionAvailable
        ? Opacity(
            opacity: contentOpacity,
            child: AppTextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                backgroundColor: palette.accentSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                actionLabel!,
                style: AppFonts.label(
                  color: palette.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.textPrimary.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface,
                Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.08),
                  colors.surface,
                ),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackActionBelow =
                    actionWidget != null && constraints.maxWidth < 360;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: iconOpacity,
                      child: _SnackIconChip(
                        colors: colors,
                        palette: palette,
                        size: compact ? 38 : 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: stackActionBelow
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                messageWidget,
                                const SizedBox(height: 10),
                                actionWidget,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: messageWidget),
                                if (actionWidget != null) ...[
                                  const SizedBox(width: 10),
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: actionWidget,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackIconChip extends StatelessWidget {
  const _SnackIconChip({
    required this.colors,
    required this.palette,
    required this.size,
  });

  final AppColor colors;
  final _SnackPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colors.onPrimary.withValues(alpha: 0.14),
              palette.accent,
            ),
            palette.accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(palette.icon, size: size * 0.46, color: palette.foreground),
    );
  }
}

bool _showTopOverlayToast(
  BuildContext context, {
  required double top,
  required double left,
  required double right,
  required AppColor colors,
  required _SnackPalette palette,
  required String message,
  required TextStyle? textStyle,
  required Duration duration,
  VoidCallback? onTap,
  String? actionLabel,
  VoidCallback? onAction,
  String? semanticsLabel,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;

  _removeCurrentTopSnack();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TopSnackAnimated(
      top: top,
      left: left,
      right: right,
      colors: colors,
      palette: palette,
      message: message,
      textStyle: textStyle,
      duration: duration,
      onClose: () {
        if (identical(_currentTopSnack, entry)) {
          _removeCurrentTopSnack();
        }
      },
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      semanticsLabel: semanticsLabel,
    ),
  );

  overlay.insert(entry);
  _currentTopSnack = entry;
  return true;
}

class _TopSnackAnimated extends StatefulWidget {
  const _TopSnackAnimated({
    required this.top,
    required this.left,
    required this.right,
    required this.colors,
    required this.palette,
    required this.message,
    required this.textStyle,
    required this.duration,
    required this.onClose,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.semanticsLabel,
  });

  final double top;
  final double left;
  final double right;
  final AppColor colors;
  final _SnackPalette palette;
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 980),
    reverseDuration: const Duration(milliseconds: 520),
  );

  Timer? _dismissTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isClosing) return;
    _isClosing = true;
    _dismissTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    const maxCardWidth = 680.0;

    return Positioned(
      top: widget.top,
      left: widget.left,
      right: widget.right,
      child: Material(
        type: MaterialType.transparency,
        child: IgnorePointer(
          ignoring: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxCardWidth),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value.clamp(0.0, 1.0);
                  final isReversing =
                      _controller.status == AnimationStatus.reverse ||
                      _isClosing;

                  final drop = Curves.easeInCubic.transform(
                    _interval(progress, 0.0, 0.3),
                  );
                  final impact = Curves.easeOutBack.transform(
                    _interval(progress, 0.3, 0.52),
                  );
                  final bloom = Curves.easeOutCubic.transform(
                    _interval(progress, 0.44, 0.86),
                  );
                  final content = Curves.easeOut.transform(
                    _interval(progress, 0.58, 1.0),
                  );
                  final exit = Curves.easeInOutCubic.transform(1.0 - progress);

                  final chipTravel = isReversing
                      ? 0.0
                      : (lerpDouble(-42, 0, drop) ?? 0);
                  final chipScale = isReversing
                      ? 1.0
                      : (lerpDouble(0.82, 1.0, drop) ?? 1);
                  final chipStretchX = isReversing
                      ? 1.0
                      : (lerpDouble(0.72, 1.08, impact) ?? 1);
                  final chipStretchY = isReversing
                      ? 1.0
                      : (lerpDouble(1.24, 0.92, impact) ?? 1);
                  final cardScaleX = isReversing
                      ? (lerpDouble(1.0, 0.985, exit) ?? 1)
                      : (lerpDouble(0.9, 1.0, bloom) ?? 1);
                  final cardScaleY = isReversing
                      ? (lerpDouble(1.0, 0.95, exit) ?? 1)
                      : (lerpDouble(0.72, 1.0, bloom) ?? 1);
                  final cardOpacity = isReversing
                      ? (lerpDouble(1.0, 0.0, exit) ?? 1)
                      : (lerpDouble(0.0, 1.0, bloom) ?? 1);
                  final cardTravel = isReversing
                      ? (lerpDouble(0.0, -16.0, exit) ?? 0)
                      : (lerpDouble(22.0, 0.0, bloom) ?? 0);

                  final snackCard = _SnackSurface(
                    colors: widget.colors,
                    palette: widget.palette,
                    message: widget.message,
                    textStyle: widget.textStyle,
                    actionLabel: widget.actionLabel,
                    onAction: widget.onAction == null
                        ? null
                        : () {
                            widget.onAction?.call();
                            _dismiss();
                          },
                    semanticsLabel: widget.semanticsLabel,
                    compact: true,
                    contentOpacity: isReversing
                        ? (lerpDouble(1.0, 0.0, exit) ?? 1)
                        : content,
                    iconOpacity: isReversing
                        ? (lerpDouble(1.0, 0.0, exit) ?? 1)
                        : content,
                  );

                  return Dismissible(
                    key: const ValueKey('animated_top_snack'),
                    direction: DismissDirection.horizontal,
                    resizeDuration: null,
                    onDismissed: (_) => widget.onClose(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Transform.translate(
                            offset: Offset(0, cardTravel),
                            child: Opacity(
                              opacity: cardOpacity,
                              child: Transform.scale(
                                scaleX: cardScaleX,
                                scaleY: cardScaleY,
                                alignment: Alignment.topCenter,
                                child: widget.onTap == null
                                    ? snackCard
                                    : Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            widget.onTap?.call();
                                            _dismiss();
                                          },
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: snackCard,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        if (!isReversing)
                          Transform.translate(
                            offset: Offset(0, chipTravel),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                chipScale * chipStretchX,
                                chipScale * chipStretchY,
                                1,
                              ),
                              child: IgnorePointer(
                                ignoring: true,
                                child: _OrbDropChip(
                                  colors: widget.colors,
                                  palette: widget.palette,
                                  collapse: bloom,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _interval(double t, double begin, double end) {
  if (t <= begin) return 0.0;
  if (t >= end) return 1.0;
  return ((t - begin) / (end - begin)).clamp(0.0, 1.0);
}

class _OrbDropChip extends StatelessWidget {
  const _OrbDropChip({
    required this.colors,
    required this.palette,
    required this.collapse,
  });

  final AppColor colors;
  final _SnackPalette palette;
  final double collapse;

  @override
  Widget build(BuildContext context) {
    final width = lerpDouble(52, 22, collapse) ?? 22;
    final height = lerpDouble(52, 22, collapse) ?? 22;
    final opacity = lerpDouble(1.0, 0.0, collapse) ?? 0.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color.alphaBlend(
                colors.onPrimary.withValues(alpha: 0.16),
                palette.accent,
              ),
              palette.accent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          palette.icon,
          color: palette.foreground,
          size: lerpDouble(22, 10, collapse),
        ),
      ),
    );
  }
}

void _removeCurrentTopSnack() {
  final entry = _currentTopSnack;
  if (entry != null && entry.mounted) {
    entry.remove();
  }
  _currentTopSnack = null;
}
