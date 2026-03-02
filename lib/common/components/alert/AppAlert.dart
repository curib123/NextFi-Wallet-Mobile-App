// lib/common/components/alert/app_alert.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';

/// Types supported by the alert.
enum AppAlertType { loading, success, error, warning, info }

/// Controller to mutate/close an open modal.
class AppAlertController {
  final void Function(
      AppAlertType type, {
      String? title,
      String? subtitle,
      String? primaryText,
      VoidCallback? onPrimary,
      }) _update;
  final VoidCallback _close;

  AppAlertController._(this._update, this._close);

  void update(
      AppAlertType type, {
        String? title,
        String? subtitle,
        String? primaryText,
        VoidCallback? onPrimary,
      }) =>
      _update(type,
          title: title,
          subtitle: subtitle,
          primaryText: primaryText,
          onPrimary: onPrimary);

  void close() => _close();
}

/// Show a modern minimalist bottom-sheet alert.
AppAlertController showAppAlert(
    BuildContext context, {
      required AppAlertType type,
      String? title,
      String? subtitle,
      String primaryText = 'OK',
      VoidCallback? onPrimary,
      bool barrierDismissible = false,
    }) {
  final notifier = _AlertStateNotifier(
    type: type,
    title: title ?? _defaultTitle(type),
    subtitle: subtitle,
    primaryText: primaryText,
    onPrimary: onPrimary,
  );

  void close() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  showGeneralDialog(
    context: context,
    barrierLabel: 'Alert',
    barrierDismissible: barrierDismissible,
    barrierColor: AppColor.of(context).surface,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => _ModalScaffold(notifier: notifier),
    transitionBuilder: (ctx, anim, _, child) {
      final curve = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.16, 1, 0.3, 1),
      );
      final fade = CurvedAnimation(
        parent: anim,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );

  void update(
      AppAlertType t, {
        String? title,
        String? subtitle,
        String? primaryText,
        VoidCallback? onPrimary,
      }) {
    notifier
      ..type = t
      ..title = title ?? _defaultTitle(t)
      ..subtitle = subtitle ?? notifier.subtitle
      ..primaryText = primaryText ?? notifier.primaryText
      ..onPrimary = onPrimary ?? notifier.onPrimary
      ..notifyListeners();
  }

  return AppAlertController._(update, close);
}

/* ───────────────────── State ───────────────────── */

class _AlertStateNotifier extends ChangeNotifier {
  _AlertStateNotifier({
    required this.type,
    required this.title,
    this.subtitle,
    required this.primaryText,
    this.onPrimary,
  });

  AppAlertType type;
  String title;
  String? subtitle;
  String primaryText;
  VoidCallback? onPrimary;
}

/* ───────────────────── Backdrop ───────────────────── */

class _ModalScaffold extends StatelessWidget {
  const _ModalScaffold({required this.notifier});
  final _AlertStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Blurred backdrop — theme-aware overlay ──
        IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              color: colors.background.withValues(alpha: 0.45),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                bottom > 0 ? bottom : 16,
              ),
              child: _AlertSheet(notifier: notifier),
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────── Sheet ───────────────────── */

class _AlertSheet extends StatelessWidget {
  const _AlertSheet({required this.notifier});
  final _AlertStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final screenH = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final v = _visualFor(notifier.type, colors);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenH * 0.65),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.background.withValues(alpha: 0.18),
                      blurRadius: 64,
                      spreadRadius: -8,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: v.color.withValues(alpha: 0.06),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DragHandle(colors: colors),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AlertIcon(visual: v, colors: colors),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeIn,
                              child: Text(
                                notifier.title,
                                key: ValueKey(notifier.title),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  height: 1.25,
                                  color: colors.textPrimary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            if ((notifier.subtitle ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  notifier.subtitle!,
                                  key: ValueKey(notifier.subtitle),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color:
                                    colors.textSecondary.withValues(alpha: 0.75),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _SheetCTA(notifier: notifier, visual: v, colors: colors),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _Visual _visualFor(AppAlertType type, AppColor c) {
    switch (type) {
      case AppAlertType.loading:
        return _Visual(type, c.info, LucideIcons.loader2);
      case AppAlertType.success:
        return _Visual(type, c.success, LucideIcons.checkCircle2);
      case AppAlertType.error:
        return _Visual(type, c.error, LucideIcons.xCircle);
      case AppAlertType.warning:
        return _Visual(type, c.warning, LucideIcons.alertTriangle);
      case AppAlertType.info:
        return _Visual(type, c.info, LucideIcons.info);
    }
  }
}

/* ───────────────────── Drag Handle ───────────────────── */

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.border.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────── Alert Icon ───────────────────── */

class _AlertIcon extends StatelessWidget {
  const _AlertIcon({required this.visual, required this.colors});
  final _Visual visual;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(visual.type),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: visual.color.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(
            color: visual.color.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: visual.type == AppAlertType.loading
                ? WavingDotsLoader(
              color: visual.color,
              dotCount: 3,
              dotSize: 4.5,
              waveHeight: 4.5,
              speed: const Duration(milliseconds: 1100),
            )
                : Icon(visual.icon, color: visual.color, size: 24),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────── CTA ───────────────────── */

class _SheetCTA extends StatelessWidget {
  const _SheetCTA({
    required this.notifier,
    required this.visual,
    required this.colors,
  });
  final _AlertStateNotifier notifier;
  final _Visual visual;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Semantics(
        button: true,
        label: notifier.primaryText,
        child: _SoftButton(
          label: notifier.primaryText,
          color: visual.color,
          textColor: colors.surface,
          onTap: () {
            HapticFeedback.lightImpact();
            final cb = notifier.onPrimary;
            if (cb != null) cb();
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}

/* ───────────────────── Soft Button ───────────────────── */

class _SoftButton extends StatefulWidget {
  const _SoftButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<_SoftButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 60),
    reverseDuration: const Duration(milliseconds: 200),
  );

  double get _scale => 1.0 - (_ctrl.value * 0.03);
  double get _opacity => 1.0 - (_ctrl.value * 0.12);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  void _down(_) => _ctrl.forward();
  void _up(_) => _ctrl.reverse();
  void _cancel() => _ctrl.reverse();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      child: Opacity(
        opacity: _opacity,
        child: Transform.scale(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            height: 52,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.20),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────── Helpers ───────────────────── */

class _Visual {
  final AppAlertType type;
  final Color color;
  final IconData icon;
  const _Visual(this.type, this.color, this.icon);
}

String _defaultTitle(AppAlertType t) {
  switch (t) {
    case AppAlertType.loading:
      return 'Please wait...';
    case AppAlertType.success:
      return 'Success';
    case AppAlertType.error:
      return 'Something went wrong';
    case AppAlertType.warning:
      return 'Heads up';
    case AppAlertType.info:
      return 'Information';
  }
}
