// lib/common/components/alert/app_alert.dart
import 'dart:ui';
import 'package:flutter/material.dart';
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
      _update(
        type,
        title: title,
        subtitle: subtitle,
        primaryText: primaryText,
        onPrimary: onPrimary,
      );

  void close() => _close();
}

/// Show a modern minimalist bottom-sheet modal.
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
    barrierLabel: 'Modal',
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => _ModalScaffold(notifier: notifier),
    transitionBuilder: (ctx, anim, _, child) {
      final slide = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
      final fade  = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(slide),
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

/* ─────────────────────────── State ─────────────────────────── */

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

/* ─────────────────────────── Backdrop scaffold ─────────────────────────── */

class _ModalScaffold extends StatelessWidget {
  const _ModalScaffold({required this.notifier});
  final _AlertStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Frosted backdrop
        IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(color: Colors.black.withOpacity(0.38)),
          ),
        ),
        // Sheet pinned to bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12, 0, 12,
                insets.bottom > 0 ? insets.bottom : 12,
              ),
              child: _AppAlertSheet(notifier: notifier),
            ),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────────── Sheet ─────────────────────────── */

class _AppAlertSheet extends StatelessWidget {
  const _AppAlertSheet({required this.notifier});
  final _AlertStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors  = AppColor.of(context);
    final screenH = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final v = _visualFor(notifier.type, colors);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenH * 0.70),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: v.color.withOpacity(0.15),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 48,
                      spreadRadius: -4,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: v.color.withOpacity(0.09),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                // IntrinsicHeight avoids Expanded-in-unbounded-height issues.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Accent header ──────────────────
                    _SheetHeader(visual: v),

                    // ── Scrollable body ─────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeIn,
                              child: Text(
                                notifier.title,
                                key: ValueKey(notifier.title),
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                  color: colors.textPrimary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),

                            // Subtitle
                            if ((notifier.subtitle ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  notifier.subtitle!,
                                  key: ValueKey(notifier.subtitle),
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: colors.textSecondary,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── Footer / CTA ────────────────────
                    _SheetFooter(notifier: notifier, visual: v),
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
        return _Visual(type, c.info,    LucideIcons.loader2);
      case AppAlertType.success:
        return _Visual(type, c.success, LucideIcons.checkCircle2);
      case AppAlertType.error:
        return _Visual(type, c.error,   LucideIcons.xCircle);
      case AppAlertType.warning:
        return _Visual(type, c.warning, LucideIcons.alertTriangle);
      case AppAlertType.info:
        return _Visual(type, c.info,    LucideIcons.info);
    }
  }
}

/* ─────────────────────────── Header ─────────────────────────── */

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.visual});
  final _Visual visual;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            visual.color.withOpacity(0.12),
            visual.color.withOpacity(0.03),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: visual.color.withOpacity(0.10), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated icon badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _IconBadge(key: ValueKey(visual.type), visual: visual),
          ),

          const SizedBox(width: 14),

          // Status label + decorative lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusLabel(visual.type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: visual.color,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: visual.color.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: visual.color.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 8,
                      height: 3,
                      decoration: BoxDecoration(
                        color: visual.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Drag pill in top-right
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppAlertType t) {
    switch (t) {
      case AppAlertType.loading: return 'PROCESSING';
      case AppAlertType.success: return 'COMPLETED';
      case AppAlertType.error:   return 'ERROR';
      case AppAlertType.warning: return 'WARNING';
      case AppAlertType.info:    return 'NOTICE';
    }
  }
}

/* ─────────────────────────── Footer ─────────────────────────── */

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({required this.notifier, required this.visual});
  final _AlertStateNotifier notifier;
  final _Visual visual;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border.withOpacity(0.09), width: 1),
        ),
      ),
      child: Semantics(
        button: true,
        label: notifier.primaryText,
        child: _PrimaryButton(
          label: notifier.primaryText,
          color: visual.color,
          onTap: () {
            final cb = notifier.onPrimary;
            if (cb != null) cb();
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}

/* ─────────────────────────── Icon Badge ─────────────────────────── */

class _IconBadge extends StatelessWidget {
  const _IconBadge({super.key, required this.visual});
  final _Visual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: visual.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: visual.color.withOpacity(0.20),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: visual.type == AppAlertType.loading
          ? WavingDotsLoader(
        color: visual.color,
        dotCount: 3,
        dotSize: 5,
        waveHeight: 5,
        speed: const Duration(milliseconds: 1100),
      )
          : Icon(visual.icon, color: visual.color, size: 26),
    );
  }
}

/* ─────────────────────────── Primary Button ─────────────────────────── */

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 180),
  );

  double get _scale => 1.0 - (_ctrl.value * 0.038);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  void _down(_) => _ctrl.forward();
  void _up(_)   => _ctrl.reverse();
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
      child: Transform.scale(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                Color.alphaBlend(
                  Colors.black.withOpacity(0.10),
                  widget.color,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.30),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────────── Helpers ─────────────────────────── */

class _Visual {
  final AppAlertType type;
  final Color color;
  final IconData icon;
  const _Visual(this.type, this.color, this.icon);
}

String _defaultTitle(AppAlertType t) {
  switch (t) {
    case AppAlertType.loading: return 'Please wait…';
    case AppAlertType.success: return 'Success';
    case AppAlertType.error:   return 'Something went wrong';
    case AppAlertType.warning: return 'Heads up';
    case AppAlertType.info:    return 'Information';
  }
}