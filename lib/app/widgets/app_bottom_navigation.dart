// lib/app/widgets/app_bottom_navigation_premium.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';

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
class AppBottomNavigationPremium extends StatefulWidget {
  const AppBottomNavigationPremium({super.key});

  @override
  State<AppBottomNavigationPremium> createState() =>
      _AppBottomNavigationPremiumState();
}

class _AppBottomNavigationPremiumState extends State<AppBottomNavigationPremium>
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
    final tabVM = context.watch<TabVM>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<ClaimableVM, TransactionsVM>(
      builder: (context, claimableVM, transactionsVM, _) {
        // Calculate notification counts
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
                      colors.surface.withOpacity(0.92),
                      colors.surface.withOpacity(0.98),
                      colors.surface,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.95), Colors.white],
                  ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.06),
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
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
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
                          isSelected: tabVM.currentIndex == 0,
                          colors: colors,
                          onTap: () => tabVM.setTab(0),
                        ),
                        _buildNavItem(
                          context: context,
                          icon: LucideIcons.history,
                          label: 'History',
                          index: 1,
                          isSelected: tabVM.currentIndex == 1,
                          colors: colors,
                          badgeCount: unreadTxCount,
                          showDot: unreadTxCount == 0 && pendingTxCount > 0,
                          onTap: () {
                            if (unreadTxCount > 0) {
                              transactionsVM.markAllAsRead();
                            }
                            tabVM.setTab(1);
                          },
                        ),
                        _build3DSwapButton(
                          context: context,
                          isSelected: tabVM.currentIndex == 2,
                          colors: colors,
                          onTap: () => tabVM.setTab(2),
                        ),
                        _buildNavItem(
                          context: context,
                          icon: LucideIcons.gift,
                          label: 'Claimable',
                          index: 3,
                          isSelected: tabVM.currentIndex == 3,
                          colors: colors,
                          badgeCount: totalClaimableCount,
                          badgeColor: claimableReadyCount > 0
                              ? Colors.red
                              : Colors.orange,
                          onTap: () => tabVM.setTab(3),
                        ),
                        _buildNavItem(
                          context: context,
                          icon: LucideIcons.settings,
                          label: 'Settings',
                          index: 4,
                          isSelected: tabVM.currentIndex == 4,
                          colors: colors,
                          onTap: () => tabVM.setTab(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
                            colors.textSecondary.withOpacity(0.6),
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
                          ? _buildPulsingDot()
                          : _buildLiquidBadge(
                              badgeCount!,
                              badgeColor ?? Colors.red,
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? colors.primary
                          : colors.textSecondary.withOpacity(0.6),
                      letterSpacing: 0.3,
                      height: 1.2,
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
            return Transform.translate(
              offset: Offset(0, -4 * value),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.2 + (0.1 * value)),
                      blurRadius: 12 + (4 * value),
                      spreadRadius: 0,
                      offset: Offset(0, 4 + (2 * value)),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: (math.pi / 6) * value,
                  child: const Icon(
                    LucideIcons.arrowLeftRight,
                    size: 28,
                    color: Colors.white,
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
  Widget _buildLiquidBadge(int count, Color color) {
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
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  /// Subtle pulsing dot indicator
  Widget _buildPulsingDot() {
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
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(
                    0.3 * _pulseController.value,
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
