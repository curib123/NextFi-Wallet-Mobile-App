// lib/common/components/modal/login_success_modal.dart

import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/profile_avatar/user_avatar.dart';
import 'package:next_fi/services/oath2.0/models/user_model.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

Future<void> showLoginSuccessModal(BuildContext context, {required User user}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Success',
    barrierColor: AppColor.of(context).textPrimary.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) {
      return Material(
        type: MaterialType.transparency,
        child: _LoginSuccessModal(user: user),
      );
    },
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _LoginSuccessModal extends StatefulWidget {
  final User user;
  const _LoginSuccessModal({required this.user});

  @override
  State<_LoginSuccessModal> createState() => _LoginSuccessModalState();
}

class _LoginSuccessModalState extends State<_LoginSuccessModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _avatarScale;
  late Animation<double> _avatarOpacity;
  late Animation<double> _badgeScale;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    _avatarOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _avatarScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.elasticOut),
      ),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue(BuildContext context) {
    Navigator.pop(context);
    Phoenix.rebirth(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceColor = isDark
        ? colors.surface.withValues(alpha: 0.98)
        : colors.onPrimary;
    final dividerColor = isDark
        ? colors.border.withValues(alpha: 0.65)
        : colors.textPrimary.withValues(alpha: 0.06);
    final primaryTextColor = colors.textPrimary;
    final secondaryTextColor = colors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: surfaceColor,
            border: Border.all(color: dividerColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: isDark ? 0.42 : 0.12,
                ),
                blurRadius: 48,
                spreadRadius: -4,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: isDark ? 0.18 : 0.05,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top accent strip ──────────────────────────────────
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.0),
                        colors.primary,
                        colors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Large centered avatar with check badge ────
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Soft glow ring behind avatar
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primary.withValues(alpha: 0.08),
                                ),
                              ),
                              // Avatar
                              FadeTransition(
                                opacity: _avatarOpacity,
                                child: ScaleTransition(
                                  scale: _avatarScale,
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 2.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: UserAvatar(
                                        user: widget.user,
                                        radius: 44,
                                        colors: colors,
                                        backgroundColor: colors.primary
                                            .withValues(alpha: 0.15),
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Check badge — bottom-right of avatar
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: ScaleTransition(
                                  scale: _badgeScale,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.primary,
                                      border: Border.all(
                                        color: surfaceColor,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: Icon(
                                      LucideIcons.check,
                                      size: 13,
                                      color: AppColor.of(context).onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      // ── Name + email + verified pill ──────────────
                      FadeTransition(
                        opacity: _contentFade,
                        child: Column(
                          children: [
                            Text(
                              widget.user.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.4,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.user.email,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: secondaryTextColor,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: colors.primary.withValues(alpha: 0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 12,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Divider ───────────────────────────────────
                      Container(height: 1, color: dividerColor),

                      const SizedBox(height: 20),

                      // ── Welcome text ──────────────────────────────
                      FadeTransition(
                        opacity: _contentFade,
                        child: Column(
                          children: [
                            Text(
                              'Welcome back',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "You're signed in and ready to go.",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Continue button ───────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AppElevatedButton(
                          onPressed: () => _continue(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: AppColor.of(context).onPrimary,
                            elevation: 0,
                            shadowColor: AppColor.of(context).surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(LucideIcons.arrowRight, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
