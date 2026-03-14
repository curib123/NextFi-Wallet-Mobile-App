import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/utils/link_opener.dart';
import 'package:next_fi/core/services/announcements/announcements_service.dart';

class AnnouncementModalResult {
  const AnnouncementModalResult({required this.dismissed});
  final bool dismissed;
}

Future<AnnouncementModalResult?> showAnnouncementModal(
  BuildContext context, {
  required AnnouncementItem item,
  bool forceBlocking = false,
}) {
  final blocking = forceBlocking || item.isCompulsory || item.isForceUpdate;
  return showGeneralDialog<AnnouncementModalResult>(
    context: context,
    barrierDismissible: !blocking,
    barrierLabel: 'Announcement',
    barrierColor: AppColor.of(context).textPrimary.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => _AnnouncementModal(
      item: item,
      blocking: blocking,
    ),
    transitionBuilder: (_, anim, __, child) {
      final fade = CurvedAnimation(
        parent: anim,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      );
      final slide = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(slide),
          child: child,
        ),
      );
    },
  );
}

class _AnnouncementModal extends StatelessWidget {
  const _AnnouncementModal({required this.item, required this.blocking});

  final AnnouncementItem item;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final actionUrl = item.actionUrl?.trim() ?? '';
    final hasActionUrl = actionUrl.isNotEmpty;
    final accent = switch (item.type) {
      AnnouncementType.update => c.primary,
      AnnouncementType.maintenance => c.warning,
      AnnouncementType.announcement => c.success,
    };
    final icon = switch (item.type) {
      AnnouncementType.update => LucideIcons.rocket,
      AnnouncementType.maintenance => LucideIcons.wrench,
      AnnouncementType.announcement => LucideIcons.megaphone,
    };
    final tag = (item.typeLabel ?? item.type.name).trim().isNotEmpty
        ? (item.typeLabel ?? item.type.name).trim()
        : item.type.name;
    final primaryText = (item.actionLabel ?? '').trim().isNotEmpty
        ? item.actionLabel!.trim()
        : (hasActionUrl ? 'Open' : 'Continue');
    final dismissText = (item.dismissLabel ?? '').trim().isNotEmpty
        ? item.dismissLabel!.trim()
        : 'Later';

    return PopScope(
      canPop: !blocking,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: screenHeight * 0.88,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: c.border.withValues(alpha: 0.22)),
                      boxShadow: [
                        BoxShadow(
                          color: c.textPrimary.withValues(alpha: 0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: accent.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: hasActionUrl
                              ? () => LinkOpener.open(
                                    context,
                                    actionUrl,
                                    fallbackLabel: primaryText,
                                  )
                              : null,
                          child: _HeroArt(
                            item: item,
                            accent: accent,
                            icon: icon,
                            tag: tag,
                            blocking: blocking,
                            linked: hasActionUrl,
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              color: c.textPrimary,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.6,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _MetaPill(
                                                label: tag,
                                                accent: accent,
                                                background:
                                                    accent.withValues(alpha: 0.1),
                                              ),
                                              if (item.isCompulsory)
                                                _MetaPill(
                                                  label: 'Required',
                                                  accent: c.error,
                                                  background:
                                                      c.error.withValues(alpha: 0.1),
                                                ),
                                              if (item.minAppVersion != null &&
                                                  item.minAppVersion!.isNotEmpty)
                                                _MetaPill(
                                                  label:
                                                      'Min ${item.minAppVersion}',
                                                  accent: c.textPrimary,
                                                  background: c.background,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!blocking)
                                      IconButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.of(context).pop(
                                            const AnnouncementModalResult(
                                              dismissed: true,
                                            ),
                                          );
                                        },
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  item.message,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 14.5,
                                    height: 1.62,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    if (!blocking) ...[
                                      Expanded(
                                        child: SizedBox(
                                          height: 50,
                                          child: AppOutlinedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop(
                                                const AnnouncementModalResult(
                                                  dismissed: true,
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: c.textPrimary,
                                              side: BorderSide(
                                                color:
                                                    c.border.withValues(alpha: 0.35),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: Text(
                                              dismissText,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: AppElevatedButton(
                                          onPressed: () async {
                                            if (blocking && !hasActionUrl) {
                                              HapticFeedback.heavyImpact();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Action link unavailable. Please contact support.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            if (hasActionUrl) {
                                              await LinkOpener.open(
                                                context,
                                                actionUrl,
                                                fallbackLabel: primaryText,
                                              );
                                            }
                                            if (!context.mounted) return;
                                            Navigator.of(context).pop(
                                              const AnnouncementModalResult(
                                                dismissed: true,
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent,
                                            foregroundColor: c.onPrimary,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            primaryText,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

class _HeroArt extends StatelessWidget {
  const _HeroArt({
    required this.item,
    required this.accent,
    required this.icon,
    required this.tag,
    required this.blocking,
    required this.linked,
  });

  final AnnouncementItem item;
  final Color accent;
  final IconData icon;
  final String tag;
  final bool blocking;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            accent.withValues(alpha: 0.08),
            c.background.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: _GlowOrb(color: accent.withValues(alpha: 0.22), size: 140),
          ),
          Positioned(
            bottom: -48,
            left: -24,
            child: _GlowOrb(color: accent.withValues(alpha: 0.12), size: 180),
          ),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            _AnnouncementImage(imageUrl: item.imageUrl!, accent: accent)
          else
            _FallbackArt(accent: accent, icon: icon),
          Positioned(
            left: 18,
            right: 18,
            top: 18,
            child: Row(
              children: [
                _MetaPill(
                  label: tag.toUpperCase(),
                  accent: Colors.white,
                  background: Colors.black.withValues(alpha: 0.22),
                  borderColor: Colors.white.withValues(alpha: 0.18),
                ),
                const Spacer(),
                if (blocking)
                  _MetaPill(
                    label: 'ACTION REQUIRED',
                    accent: Colors.white,
                    background: accent.withValues(alpha: 0.88),
                    borderColor: accent.withValues(alpha: 0.9),
                  )
                else if (linked)
                  _MetaPill(
                    label: 'OPEN LINK',
                    accent: Colors.white,
                    background: Colors.black.withValues(alpha: 0.22),
                    borderColor: Colors.white.withValues(alpha: 0.18),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.surface.withValues(alpha: 0.0),
                      c.surface.withValues(alpha: 0.35),
                      c.surface.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementImage extends StatelessWidget {
  const _AnnouncementImage({required this.imageUrl, required this.accent});

  final String imageUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _FallbackArt(accent: accent, icon: LucideIcons.image);
      },
      errorBuilder: (_, __, ___) {
        return _FallbackArt(accent: accent, icon: LucideIcons.imageOff);
      },
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.accent, required this.icon});

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Icon(icon, size: 34, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.accent,
    required this.background,
    this.borderColor,
  });

  final String label;
  final Color accent;
  final Color background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? accent.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

