import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/auth/models/user_model.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/widgets/profile_avatar/user_avatar.dart';

Future<void> showLoginSuccessModal(BuildContext context, {required User user}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Success',
    barrierColor: AppColor.of(context).textPrimary.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 260),
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
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _LoginSuccessModal extends StatefulWidget {
  const _LoginSuccessModal({required this.user});

  final User user;

  @override
  State<_LoginSuccessModal> createState() => _LoginSuccessModalState();
}

class _LoginSuccessModalState extends State<_LoginSuccessModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _avatarOpacity;
  late final Animation<double> _avatarScale;
  late final Animation<double> _badgeScale;
  late final Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();

    _avatarOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _avatarScale = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _badgeScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.72, curve: Curves.easeOutBack),
      ),
    );
    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 1.0, curve: Curves.easeOut),
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
    final displayName = widget.user.name.trim().isEmpty
        ? 'Signed in'
        : widget.user.name.trim();

    final surfaceColor = colors.surface;
    final borderColor = colors.border.withValues(alpha: isDark ? 0.82 : 0.72);
    final strongShadow = isDark
        ? Colors.black.withValues(alpha: 0.34)
        : colors.textPrimary.withValues(alpha: 0.10);
    final softShadow = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : colors.textPrimary.withValues(alpha: 0.05);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: FadeTransition(
          opacity: _contentOpacity,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: strongShadow,
                  blurRadius: 28,
                  spreadRadius: -8,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: softShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                          FadeTransition(
                            opacity: _avatarOpacity,
                            child: ScaleTransition(
                              scale: _avatarScale,
                              child: ClipOval(
                                child: UserAvatar(
                                  user: widget.user,
                                  radius: 34,
                                  colors: colors,
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: ScaleTransition(
                              scale: _badgeScale,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: surfaceColor,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.check,
                                  size: 12,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Signed In',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.2,
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
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          size: 12,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Account verified',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You're signed in and your wallet is ready.",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: AppElevatedButton(
                      onPressed: () => _continue(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
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
          ),
        ),
      ),
    );
  }
}
