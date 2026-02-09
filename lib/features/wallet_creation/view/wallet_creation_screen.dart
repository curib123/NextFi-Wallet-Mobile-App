// lib/features/wallet_creation/view/wallet_creation_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

import 'widgets/glass_card.dart';
import 'widgets/conic_ring_avatar.dart';
import 'widgets/shimmer_text.dart';
import 'widgets/fintech_background.dart';

class WalletCreationScreen extends StatefulWidget {
  const WalletCreationScreen({super.key, this.isSplash = false});
  final bool isSplash;

  @override
  State<WalletCreationScreen> createState() => _WalletCreationScreenState();
}

class _WalletCreationScreenState extends State<WalletCreationScreen>
    with TickerProviderStateMixin {
  static const _logoAsset = 'assets/icon/icon.png';

  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_logoAsset), context);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => FintechBackground(
                    progress: _bgCtrl.value,
                    colors: colors,
                    devicePixelRatio: dpr,
                    topBandFraction: .55,
                  ),
                ),
              ),
            ),

            // Main content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    // Logo section with enhanced animations
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_bgCtrl, _pulseCtrl]),
                          builder: (_, __) {
                            final t = _bgCtrl.value * 2 * math.pi;
                            final dy = math.sin(t) * 8;
                            final tilt = math.cos(t) * 0.015;
                            final scale = 1.0 + (_pulseCtrl.value * 0.02);

                            return Transform.translate(
                              offset: Offset(0, dy),
                              child: Transform.rotate(
                                angle: tilt,
                                child: Transform.scale(
                                  scale: scale,
                                  child: FadeIn(
                                    duration: const Duration(milliseconds: 800),
                                    child: GlassCard(
                                      colors: colors,
                                      borderRadius: 32,
                                      padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Animated logo
                                          ConicRingAvatar(
                                            size: 140,
                                            ringWidth: 4,
                                            asset: _logoAsset,
                                            imageSize: 116,
                                            baseColor: colors.primary,
                                            rotationTurns: _bgCtrl.value,
                                          ),

                                          const SizedBox(height: 28),

                                          // App name with shimmer
                                          ShimmerText(
                                            "NextFI Wallet",
                                            baseColor: colors.textPrimary,
                                            highlightColor: colors.primary,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),

                                          const SizedBox(height: 12),

                                          // Tagline
                                          if (!widget.isSplash)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colors.primary.withOpacity(.08),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: colors.primary.withOpacity(.15),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildTaglineItem(
                                                    context,
                                                    icon: LucideIcons.zap,
                                                    text: 'Simple',
                                                    colors: colors,
                                                  ),
                                                  _buildDivider(colors),
                                                  _buildTaglineItem(
                                                    context,
                                                    icon: LucideIcons.shield,
                                                    text: 'Secure',
                                                    colors: colors,
                                                  ),
                                                  _buildDivider(colors),
                                                  _buildTaglineItem(
                                                    context,
                                                    icon: LucideIcons.key,
                                                    text: 'Your Keys',
                                                    colors: colors,
                                                  ),
                                                ],
                                              ),
                                            ),

                                          if (!widget.isSplash)
                                            const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Action buttons
                    if (!widget.isSplash) ...[
                      const SizedBox(height: 20),

                      // Feature highlights
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface.withOpacity(.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.primary.withOpacity(.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildFeatureItem(
                                context,
                                icon: LucideIcons.trendingUp,
                                label: 'Trade',
                                colors: colors,
                              ),
                              _buildFeatureItem(
                                context,
                                icon: LucideIcons.send,
                                label: 'Send',
                                colors: colors,
                              ),
                              _buildFeatureItem(
                                context,
                                icon: LucideIcons.repeat,
                                label: 'Swap',
                                colors: colors,
                              ),
                              _buildFeatureItem(
                                context,
                                icon: LucideIcons.piggyBank,
                                label: 'Save',
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Create wallet button
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 150),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomButton(
                            text: "Create New Wallet",
                            icon: LucideIcons.sparkles,
                            type: ButtonType.filled,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SeedPhraseScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Import wallet button
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 250),
                        child: CustomButton(
                          text: "Import Existing Wallet",
                          icon: LucideIcons.download,
                          type: ButtonType.outlined,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ImportWalletScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Splash mode tagline
            if (widget.isSplash)
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withOpacity(.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colors.primary.withOpacity(.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.shield,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Non-custodial • Open Source • Stellar Network',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your keys, your crypto, your control',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary.withOpacity(.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Version info (splash only)
            if (widget.isSplash)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: FadeIn(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    'v1.0.0 • Powered by Stellar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary.withOpacity(.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaglineItem(
      BuildContext context, {
        required IconData icon,
        required String text,
        required AppColor colors,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: colors.primary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppColor colors) {
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: colors.primary.withOpacity(.2),
    );
  }

  Widget _buildFeatureItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required AppColor colors,
      }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.primary.withOpacity(.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}