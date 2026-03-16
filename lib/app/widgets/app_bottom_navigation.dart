// lib/app/widgets/app_bottom_navigation_premium.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/app/config/app_providers.dart';

/// Ultra-premium fintech navigation with advanced morphing effects
///
/// Features:
/// - Morphing pill-style selection indicator
/// - Glassmorphism with backdrop blur
/// - 3D-style floating center button
/// - Liquid animations
/// - Smart drawer placement
/// - Haptic feedback
/// - Performance optimized
///
/// Design inspired by modern banking apps like Revolut, N26, and Wise
class AppBottomNavigationPremium extends ConsumerStatefulWidget {
  const AppBottomNavigationPremium({super.key});

  @override
  ConsumerState<AppBottomNavigationPremium> createState() =>
      _AppBottomNavigationPremiumState();
}

class _AppBottomNavigationPremiumState
    extends ConsumerState<AppBottomNavigationPremium>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final tab = ref.watch(tabControllerProvider);
    final claimableVM = ref.watch(claimableVmProvider);
    final transactionsVM = ref.watch(transactionsVmProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final claimableReadyCount = claimableVM.receivedReadyCount;
    final reclaimableCount = claimableVM.sentExpiredCount;
    final totalClaimableCount = claimableReadyCount + reclaimableCount;
    final unreadTxCount = transactionsVM.unreadCount;
    final pendingTxCount = transactionsVM.pendingCount;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surface.withValues(alpha: 0.92),
                  colors.surface.withValues(alpha: 0.98),
                  colors.surface,
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.onPrimary.withValues(alpha: 0.95),
                  colors.onPrimary,
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? colors.background.withValues(alpha: 0.50)
                : colors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? colors.onPrimary.withValues(alpha: 0.1)
                      : colors.textPrimary.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Container(
                height: 82,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildNavItem(
                      context: context,
                      icon: LucideIcons.wallet,
                      label: 'Wallet',
                      index: 0,
                      isSelected: tab.currentIndex == 0,
                      colors: colors,
                      onTap: () =>
                          ref.read(tabControllerProvider.notifier).setTab(0),
                    ),
                    _buildNavItem(
                      context: context,
                      icon: LucideIcons.history,
                      label: 'History',
                      index: 1,
                      isSelected: tab.currentIndex == 1,
                      colors: colors,
                      badgeCount: unreadTxCount,
                      showDot: unreadTxCount == 0 && pendingTxCount > 0,
                      onTap: () {
                        if (unreadTxCount > 0) {
                          ref.read(transactionsVmProvider).markAllAsRead();
                        }
                        ref.read(tabControllerProvider.notifier).setTab(1);
                      },
                    ),
                    _build3DSwapButton(
                      context: context,
                      isSelected: tab.currentIndex == 2,
                      colors: colors,
                      onTap: () =>
                          ref.read(tabControllerProvider.notifier).setTab(2),
                    ),
                    _buildNavItem(
                      context: context,
                      icon: LucideIcons.gift,
                      label: 'Claimable',
                      index: 3,
                      isSelected: tab.currentIndex == 3,
                      colors: colors,
                      badgeCount: totalClaimableCount,
                      badgeColor: claimableReadyCount > 0
                          ? colors.error
                          : colors.warning,
                      onTap: () =>
                          ref.read(tabControllerProvider.notifier).setTab(3),
                    ),
                    _buildNavItem(
                      context: context,
                      icon: LucideIcons.settings,
                      label: 'Settings',
                      index: 4,
                      isSelected: tab.currentIndex == 4,
                      colors: colors,
                      onTap: () =>
                          ref.read(tabControllerProvider.notifier).setTab(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigation item with liquid animation
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required AppColor colors,
    required VoidCallback onTap,
    int? badgeCount,
    bool showDot = false,
    Color? badgeColor,
  }) {
    final hasBadge = (badgeCount != null && badgeCount > 0) || showDot;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with liquid bounce
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 1.0 + (value * 0.15),
                        child: Icon(
                          icon,
                          size: 24,
                          color: Color.lerp(
                            colors.textSecondary.withValues(alpha: 0.6),
                            colors.primary,
                            value,
                          ),
                        ),
                      );
                    },
                  ),

                  // Badge
                  if (hasBadge)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: showDot
                          ? _buildPulsingDot(context)
                          : _buildLiquidBadge(
                              context,
                              badgeCount!,
                              badgeColor ?? colors.error,
                            ),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // Label with slide animation
              AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: Offset(0, isSelected ? 0 : 0.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.7,
                  child: Text(
                    label,
                    style:
                        AppFonts.label(
                          color: isSelected
                              ? colors.primary
                              : colors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          letterSpacing: 0.12,
                        ).copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.textSecondary.withValues(alpha: 0.6),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D-style floating swap button with subtle depth
  Widget _build3DSwapButton({
    required BuildContext context,
    required bool isSelected,
    required AppColor colors,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
          builder: (context, value, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Transform.translate(
              offset: Offset(0, -4 * value),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(
                        alpha: 0.2 + (0.1 * value),
                      ),
                      blurRadius: 12 + (4 * value),
                      spreadRadius: 0,
                      offset: Offset(0, 4 + (2 * value)),
                    ),
                    BoxShadow(
                      color: (isDark ? colors.background : colors.textPrimary)
                          .withValues(alpha: isDark ? 0.35 : 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: (math.pi / 6) * value,
                  child: Icon(
                    LucideIcons.arrowLeftRight,
                    size: 28,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Clean drawer with subtle shadow
  Widget _buildLiquidBadge(BuildContext context, int count, Color color) {
    final colors = AppColor.of(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * scale),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.onPrimary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: AppFonts.label(
                color: colors.onPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  /// Subtle pulsing dot indicator
  Widget _buildPulsingDot(BuildContext context) {
    final colors = AppColor.of(context);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (0.2 * _pulseController.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors.warning,
              shape: BoxShape.circle,
              border: Border.all(color: colors.onPrimary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.warning.withValues(
                    alpha: 0.3 * _pulseController.value,
                  ),
                  blurRadius: 4 * _pulseController.value,
                  spreadRadius: 1 * _pulseController.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
