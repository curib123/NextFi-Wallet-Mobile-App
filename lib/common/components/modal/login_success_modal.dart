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
    barrierColor: Colors.black.withOpacity(0.5),
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
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  late Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _checkScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _ripple = Tween<double>(begin: 0.6, end: 1.35).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
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
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    final cardBg = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF5F5F7);
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: surfaceColor,
            border: Border.all(
              color: dividerColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 48,
                spreadRadius: -4,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                        colors.primary.withOpacity(0.0),
                        colors.primary,
                        colors.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Animated check icon ───────────────────────
                      AnimatedBuilder(
                        animation: _checkController,
                        builder: (context, _) {
                          return SizedBox(
                            width: 88,
                            height: 88,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ripple ring
                                Opacity(
                                  opacity: (1.0 - (_ripple.value - 0.6) / 0.75)
                                      .clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: _ripple.value,
                                    child: Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.primary.withOpacity(0.3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Icon background
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary.withOpacity(0.1),
                                  ),
                                ),
                                // Check icon
                                FadeTransition(
                                  opacity: _checkOpacity,
                                  child: ScaleTransition(
                                    scale: _checkScale,
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.primary.withOpacity(0.12),
                                      ),
                                      child: Icon(
                                        LucideIcons.checkCircle2,
                                        color: colors.primary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Heading ───────────────────────────────────
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "You're signed in and ready to go.",
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── User card ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: cardBg,
                          border: Border.all(
                            color: dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              user: widget.user,
                              radius: 22,
                              colors: colors,
                              backgroundColor: colors.primary.withOpacity(0.15),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.user.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.user.email,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Verified badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: colors.primary.withOpacity(0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.shieldCheck,
                                    size: 11,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 11,
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

                      // ── Continue button ───────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: AppElevatedButton(
                          onPressed: () => _continue(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
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