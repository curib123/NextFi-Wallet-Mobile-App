// lib/common/components/alert/app_alert.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';

/// Types supported by the alert.
enum AppAlertType { loading, success, error, warning, info }

/// Controller to mutate/close an open alert.
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

/// Show a modern alert dialog. Can be started as `loading` then updated later.
///
/// Example:
/// final ctl = showAppAlert(context, type: AppAlertType.loading);
/// // ... work ...
/// ctl.update(AppAlertType.success, title: 'Sent!', subtitle: 'Funds delivered');
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

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  showGeneralDialog(
    context: context,
    barrierLabel: 'Alert',
    barrierDismissible: barrierDismissible,
    // Transparent barrier; we draw our own blur+dimmer.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _BlurredBackdrop(
      child: _AppAlertDialog(notifier: notifier),
    ),
    transitionBuilder: (_, anim, __, child) {
      final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );

  void _update(
      AppAlertType type, {
        String? title,
        String? subtitle,
        String? primaryText,
        VoidCallback? onPrimary,
      }) {
    notifier
      ..type = type
      ..title = title ?? _defaultTitle(type)
      ..subtitle = subtitle ?? notifier.subtitle
      ..primaryText = primaryText ?? notifier.primaryText
      ..onPrimary = onPrimary ?? notifier.onPrimary
      ..notifyListeners();
  }

  return AppAlertController._(_update, _close);
}

/* ─────────────────────────── Internals ─────────────────────────── */

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

/// Full-screen blur layer (behind the dialog content).
class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({
    required this.child,
    this.blurSigma = 16,
    this.tintOpacity = 0.35,
  });

  final Widget child;
  final double blurSigma;
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(color: Colors.black.withOpacity(tintOpacity)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AppAlertDialog extends StatelessWidget {
  const _AppAlertDialog({required this.notifier});
  final _AlertStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: AnimatedBuilder(
              animation: notifier,
              builder: (context, _) {
                final v = _visualFor(context, notifier.type, colors);
                final media = MediaQuery.of(context);
                final maxBodyHeight = media.size.height * 0.45;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Card
                    ClipRRect(
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        type: MaterialType.transparency,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
                            decoration: BoxDecoration(
                              color: colors.surface.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color.lerp(colors.border, v.color, 0.25)!
                                    .withOpacity(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 26,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 260,
                                maxWidth: 420,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 32), // space for bubble
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeOutCubic,
                                    child: Text(
                                      notifier.title,
                                      key: ValueKey(notifier.title),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.1,
                                        color: colors.textPrimary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  if ((notifier.subtitle ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: maxBodyHeight,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: AnimatedSwitcher(
                                          duration:
                                          const Duration(milliseconds: 180),
                                          child: Text(
                                            notifier.subtitle!,
                                            key: ValueKey(notifier.subtitle),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.42,
                                              color: colors.textSecondary,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Semantics(
                                      button: true,
                                      label: notifier.primaryText,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          final cb = notifier.onPrimary;
                                          if (cb != null) cb();
                                          Navigator.of(context).maybePop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: v.color,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          minimumSize:
                                          const Size.fromHeight(44),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          notifier.primaryText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
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

                    // Floating icon bubble (top center)
                    Positioned(
                      top: -28,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: v.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: v.color.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildIcon(v, colors),
                        ),
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

  Widget _buildIcon(_Visual v, AppColor colors) {
    if (v.type == AppAlertType.loading) {
      // Outline Rubik's cube loader inside the colored bubble
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: RubiksCubeLoader(
            size: 25,
            speed: const Duration(milliseconds: 1200),
            color: Colors.white, // outline on colored circle
          ),
        ),
      );
    }
    return Icon(v.icon, color: Colors.white, size: 28);
  }

  _Visual _visualFor(BuildContext context, AppAlertType type, AppColor c) {
    switch (type) {
      case AppAlertType.loading:
        return _Visual(type, c.info, LucideIcons.loader2); // icon unused
      case AppAlertType.success:
        return _Visual(type, c.success, LucideIcons.checkCircle2);
      case AppAlertType.error:
        return _Visual(type, c.error, LucideIcons.alertTriangle);
      case AppAlertType.warning:
        return _Visual(type, c.warning, LucideIcons.alertTriangle);
      case AppAlertType.info:
        return _Visual(type, c.info, LucideIcons.info);
    }
  }
}

class _Visual {
  final AppAlertType type;
  final Color color;
  final IconData icon;
  const _Visual(this.type, this.color, this.icon);
}

String _defaultTitle(AppAlertType t) {
  switch (t) {
    case AppAlertType.loading:
      return 'Please wait…';
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

