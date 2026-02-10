// lib/features/wallet_creation/view/wallet_creation_screen.dart
import 'dart:math' as math;
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
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'assets/icon/icon.png';

  late final AnimationController _bgCtrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 22))
    ..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_logoAsset), context);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => FintechBackground(
                  progress: _bgCtrl.value,
                  colors: colors,
                  devicePixelRatio: dpr,
                  topBandFraction: .45,
                ),
              ),
            ),

            // Foreground content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _bgCtrl,
                        builder: (_, __) {
                          final t = _bgCtrl.value * 2 * math.pi;
                          final dy = math.sin(t) * 6;
                          final tilt = math.cos(t) * 0.02;
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: Transform.rotate(
                              angle: tilt,
                              child: GlassCard(
                                colors: colors,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ConicRingAvatar(
                                        size: 112,
                                        ringWidth: 3,
                                        asset: _logoAsset,
                                        imageSize: 96,
                                        baseColor: colors.primary,
                                        rotationTurns: _bgCtrl.value,
                                      ),
                                      const SizedBox(height: 16),
                                      ShimmerText(
                                        "NextFI Wallet",
                                        baseColor: colors.textPrimary,
                                        highlightColor: colors.primary,
                                      ),
                                      const SizedBox(height: 6),
                                      if (!widget.isSplash)
                                        Text(
                                          'Simple\u202F•\u202FUser Controlled\u202F•\u202FSecure',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                            height: 1.4,
                                            letterSpacing: .2,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  if (!widget.isSplash) ...[
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 120),
                      child: CustomButton(
                        text: "Create New Wallet",
                        icon: LucideIcons.plusCircle,
                        type: ButtonType.filled,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 220),
                      child: CustomButton(
                        text: "Import Wallet",
                        icon: LucideIcons.download,
                        type: ButtonType.outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (widget.isSplash)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Simple\u202F•\u202FUser Controlled\u202F•\u202FSecure',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                      height: 1.4,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}