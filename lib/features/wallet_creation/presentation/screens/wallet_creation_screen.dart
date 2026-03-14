// lib/features/wallet_creation/view/wallet_creation_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart'; // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ NEW

import 'package:next_fi/features/import_wallet/presentation/screens/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/screens/seed_phrase_screen.dart';
import 'package:next_fi/core/widgets/button/custom_button.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/app_cover/app_cover_service.dart';

import 'package:next_fi/features/wallet_creation/presentation/widgets/shimmer_text.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/fintech_background.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/conic_ring_avatar.dart';

class WalletCreationScreen extends StatefulWidget {
  const WalletCreationScreen({super.key, this.isSplash = false});
  final bool isSplash;

  @override
  State<WalletCreationScreen> createState() => _WalletCreationScreenState();
}

class _WalletCreationScreenState extends State<WalletCreationScreen>
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'assets/icon/icon.png';

  /// ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ REAL APP INFO
  String _appName = '';
  String _version = '';
  final AppCoverService _appCoverService = AppCoverService();
  AppCoverConfig? _appCover;

  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadAppInfo(); // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ load real metadata
    _loadAppCover();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _appName = info.appName;
      _version = "v${info.version} (${info.buildNumber})";
    });
  }

  Future<void> _loadAppCover() async {
    try {
      final cover = await _appCoverService.getCurrent();
      if (!mounted) return;
      setState(() => _appCover = cover);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appCover = null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_logoAsset), context);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _appCoverService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      backgroundColor: colors.background,
      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          /// ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€¦Ã¢â‚¬â„¢Ãƒâ€¦Ã¢â‚¬â„¢ FULLSCREEN Animated Background
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: _bgCtrl,
                    builder: (_, __) => FintechBackground(
                      progress: _bgCtrl.value,
                      colors: colors,
                      devicePixelRatio: dpr,
                      topBandFraction: .45,
                    ),
                  ),
                  if (_appCover?.hasUsableImage == true)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 320),
                      opacity: 1,
                      child: CachedNetworkImage(
                        imageUrl: _appCover!.imageUrl!,
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
                        colors: [
                          colors.background.withValues(alpha: 0.28),
                          colors.background.withValues(
                            alpha: _appCover?.hasUsableImage == true
                                ? 0.54
                                : 0.24,
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
          if (_appCover?.hasUsableImage == true)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),

          /// ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â§Ãƒâ€šÃ‚Â© Foreground
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  /// ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚ÂªÃƒâ€šÃ‚Âª Center Card
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
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  22,
                                  18,
                                  18,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    /// Logo
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

                                    /// ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ REAL APP NAME
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: ShimmerText(
                                          _appName.isEmpty
                                              ? "Loading..."
                                              : _appName,
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

                  /// ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒâ€¹Ã…â€œ Buttons
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
                            MaterialPageRoute(
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
                        text: "Import Wallet",
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

          /// ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚ÂÃƒâ€šÃ‚Â· Footer Tagline + Version
          if (widget.isSplash)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    Text(
                      'Simple\u202FÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢\u202FUser Controlled\u202FÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢\u202FSecure',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                        height: 1.4,
                        letterSpacing: .2,
                      ),
                    ),
                    if (_version.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _version,
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

