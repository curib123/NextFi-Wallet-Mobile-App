import 'dart:math' as math;

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/custom_button.dart';
import 'package:next_fi/features/import_wallet/presentation/screens/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/screens/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_creation/presentation/viewmodels/wallet_creation_controller.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/conic_ring_avatar.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/fintech_background.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/shimmer_text.dart';

class WalletCreationScreen extends ConsumerStatefulWidget {
  const WalletCreationScreen({super.key, this.isSplash = false});

  final bool isSplash;

  @override
  ConsumerState<WalletCreationScreen> createState() =>
      _WalletCreationScreenState();
}

class _WalletCreationScreenState extends ConsumerState<WalletCreationScreen>
    with SingleTickerProviderStateMixin {
  static const String _logoAsset = 'assets/icon/icon.png';

  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

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
    final walletCreation = ref.watch(walletCreationControllerProvider);
    final colors = AppColor.of(context);
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final appCover = walletCreation.appCover;
    final bool hasCover = appCover?.hasUsableImage == true;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _bgCtrl,
                    builder: (_, __) => FintechBackground(
                      progress: _bgCtrl.value,
                      colors: colors,
                      devicePixelRatio: dpr,
                      topBandFraction: .45,
                    ),
                  ),
                  if (hasCover)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 320),
                      opacity: 1,
                      child: CachedNetworkImage(
                        imageUrl: appCover!.imageUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 260),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          colors.background.withValues(alpha: 0.28),
                          colors.background.withValues(
                            alpha: hasCover ? 0.54 : 0.24,
                          ),
                          colors.background.withValues(alpha: 0.84),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasCover)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _bgCtrl,
                        builder: (_, __) {
                          final double t = _bgCtrl.value * 2 * math.pi;
                          final double dy = math.sin(t) * 6;
                          final double tilt = math.cos(t) * 0.02;

                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: Transform.rotate(
                              angle: tilt,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  22,
                                  18,
                                  18,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    ConicRingAvatar(
                                      size: 114,
                                      ringWidth: 5,
                                      asset: _logoAsset,
                                      imageSize: 86,
                                      baseColor: colors.primary,
                                      fillColor: colors.surface,
                                      imagePadding: 11,
                                      rotationTurns: _bgCtrl.value,
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: ShimmerText(
                                          walletCreation.appName.isEmpty
                                              ? 'Loading...'
                                              : walletCreation.appName,
                                          baseColor: colors.textPrimary,
                                          highlightColor: colors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (!widget.isSplash) ...<Widget>[
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 120),
                      child: CustomButton(
                        text: 'Create New Wallet',
                        icon: LucideIcons.plusCircle,
                        type: ButtonType.filled,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const SeedPhraseScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      delay: const Duration(milliseconds: 220),
                      child: CustomButton(
                        text: 'Import Wallet',
                        icon: LucideIcons.download,
                        type: ButtonType.outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
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
          if (widget.isSplash)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Simple - User Controlled - Secure',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                        height: 1.4,
                        letterSpacing: .2,
                      ),
                    ),
                    if (walletCreation.version.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        walletCreation.version,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary.withValues(alpha: 0.82),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
