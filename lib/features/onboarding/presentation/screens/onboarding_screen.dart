import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/services/app_cover/app_cover_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController = PageController(
    viewportFraction: 0.9,
  );
  final AppCoverService _appCoverService = AppCoverService();
  int _currentIndex = 0;
  bool _finishing = false;
  AppCoverConfig? _appCover;

  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      eyebrow: 'SELF-CUSTODY',
      title: 'Your wallet stays in your hands.',
      body:
          'NextFi is non-custodial, so your wallet and recovery phrase stay with you.',
      accentSeed: Color(0xFF2D6BFF),
      icon: Icons.verified_user_rounded,
      statsLabel: 'Built for trust',
      statsValue: 'User-controlled',
      bullets: <String>[
        'Own your wallet keys',
        'Secure with PIN or biometrics',
        'Send funds without giving up custody',
      ],
    ),
    _OnboardingSlide(
      eyebrow: 'FAST PAYMENTS',
      title: 'Send and receive with less friction.',
      body: 'Move XLM and USDC with a cleaner flow built for everyday use.',
      accentSeed: Color(0xFF12A594),
      icon: Icons.send_rounded,
      statsLabel: 'Made for motion',
      statsValue: 'XLM + USDC ready',
      bullets: <String>[
        'Quick send and receive actions',
        'Mobile-first wallet flows',
        'Clear review before confirm',
      ],
    ),
    _OnboardingSlide(
      eyebrow: 'P2P ACCESS',
      title: 'Trade into local cash when you need it.',
      body: 'Buy, sell, and convert with a simpler peer-to-peer trade flow.',
      accentSeed: Color(0xFF8A5CFF),
      icon: Icons.swap_horiz_rounded,
      statsLabel: 'Flexible access',
      statsValue: 'Crypto to cash',
      bullets: <String>[
        'Use simple P2P trade flows',
        'Review each step clearly',
        'Keep payments and trading in one wallet',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppCover();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _appCoverService.dispose();
    super.dispose();
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

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onFinish();
    if (!mounted) return;
    setState(() => _finishing = false);
  }

  Future<void> _goToPage(int index) async {
    if (index < 0 || index >= _slides.length) return;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_currentIndex == _slides.length - 1) {
      await _finish();
      return;
    }
    await _goToPage(_currentIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slide = _slides[_currentIndex];
    final hasCover = _appCover?.hasUsableImage == true;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    slide.accentSeed.withValues(alpha: isDark ? 0.16 : 0.12),
                    colors.background,
                    colors.background,
                  ],
                  stops: const <double>[0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          if (hasCover)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: _appCover!.imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 260),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    colors.background.withValues(
                      alpha: hasCover ? (isDark ? 0.26 : 0.18) : 0.0,
                    ),
                    colors.background.withValues(
                      alpha: hasCover
                          ? (isDark ? 0.58 : 0.50)
                          : (isDark ? 0.08 : 0.04),
                    ),
                    colors.background.withValues(
                      alpha: hasCover
                          ? (isDark ? 0.86 : 0.82)
                          : (isDark ? 0.18 : 0.10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Stack(
            children: <Widget>[
              Positioned(
                top: -100,
                right: -32,
                child: _AmbientGlow(
                  color: slide.accentSeed,
                  size: 220,
                  opacity: isDark ? 0.16 : 0.14,
                ),
              ),
              Positioned(
                bottom: -120,
                left: -48,
                child: _AmbientGlow(
                  color: colors.primary,
                  size: 260,
                  opacity: isDark ? 0.12 : 0.10,
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxHeight < 780;
                    final EdgeInsets padding = EdgeInsets.fromLTRB(
                      compact ? 16 : 20,
                      12,
                      compact ? 16 : 20,
                      compact ? 16 : 20,
                    );

                    return Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _OnboardingHeader(
                            colors: colors,
                            hasCover: hasCover,
                            slideIndex: _currentIndex,
                            slideCount: _slides.length,
                            onSkip: _finishing ? null : _finish,
                          ),
                          SizedBox(height: compact ? 14 : 20),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (int index) {
                                setState(() => _currentIndex = index);
                              },
                              itemBuilder: (BuildContext context, int index) {
                                return _OnboardingHeroCard(
                                  slide: _slides[index],
                                  isActive: index == _currentIndex,
                                  isDark: isDark,
                                  colors: colors,
                                  compact: compact,
                                  hasCover: hasCover,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          _OnboardingFooter(
                            slideIndex: _currentIndex,
                            slideCount: _slides.length,
                            colors: colors,
                            isDark: isDark,
                            hasCover: hasCover,
                            finishing: _finishing,
                            onBack: _currentIndex == 0 || _finishing
                                ? null
                                : () => _goToPage(_currentIndex - 1),
                            onNext: _finishing ? null : _next,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.colors,
    required this.hasCover,
    required this.slideIndex,
    required this.slideCount,
    required this.onSkip,
  });

  final AppColor colors;
  final bool hasCover;
  final int slideIndex;
  final int slideCount;
  final Future<void> Function()? onSkip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 10,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _GlassPill(
              colors: colors,
              hasCover: hasCover,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NextFi Wallet',
                    style: AppFonts.sora(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _GlassPill(
              colors: colors,
              hasCover: hasCover,
              child: Text(
                '${slideIndex + 1} of $slideCount',
                style: AppFonts.sora(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Text(
            'Skip',
            style: AppFonts.sora(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _OnboardingHeroCard extends StatelessWidget {
  const _OnboardingHeroCard({
    required this.slide,
    required this.isActive,
    required this.isDark,
    required this.colors,
    required this.compact,
    required this.hasCover,
  });

  final _OnboardingSlide slide;
  final bool isActive;
  final bool isDark;
  final AppColor colors;
  final bool compact;
  final bool hasCover;

  @override
  Widget build(BuildContext context) {
    final Color accent = slide.accentSeed;
    final double scale = isActive ? 1.0 : 0.96;
    final double textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      scale: scale,
      curve: Curves.easeOutCubic,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool tightCard =
              constraints.maxHeight < 210 ||
              constraints.maxWidth < 320 ||
              textScale > 1.05;
          final bool veryTightCard =
              constraints.maxHeight < 420 ||
              constraints.maxWidth < 300 ||
              textScale > 1.20;
          final bool mergedCard = constraints.maxHeight >= 360;

          final double statsLabelSize = veryTightCard
              ? 8.8
              : (tightCard ? 9.2 : 10);
          final double statsValueSize = veryTightCard
              ? 10.2
              : (tightCard ? 11 : 12);
          final double eyebrowSize = veryTightCard
              ? 8.8
              : (tightCard ? 9.2 : 10);
          final double titleSize = veryTightCard ? 16 : (tightCard ? 18 : 20);
          final double bodySize = veryTightCard
              ? 11
              : (tightCard ? 11.5 : 12.5);

          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: EdgeInsets.fromLTRB(
              veryTightCard ? 14 : 16,
              veryTightCard ? 14 : 16,
              veryTightCard ? 14 : 16,
              veryTightCard ? 12 : 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (hasCover ? Colors.white : colors.border).withValues(
                  alpha: hasCover ? (isDark ? 0.16 : 0.28) : 0.52,
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: isDark ? 0.24 : 0.18),
                  colors.surface.withValues(
                    alpha: hasCover
                        ? (isDark ? 0.78 : 0.82)
                        : (isDark ? 0.92 : 0.96),
                  ),
                  colors.surface.withValues(
                    alpha: hasCover
                        ? (isDark ? 0.68 : 0.76)
                        : (isDark ? 0.78 : 0.90),
                  ),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(
                    alpha: hasCover ? 0.20 : (isDark ? 0.22 : 0.16),
                  ),
                  blurRadius: hasCover ? 30 : 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(veryTightCard ? 1.0 : 1.08),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: veryTightCard ? 44 : 50,
                          height: veryTightCard ? 44 : 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.06 : 0.48,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            slide.icon,
                            size: veryTightCard ? 20 : 22,
                            color: accent,
                          ),
                        ),
                        SizedBox(width: veryTightCard ? 8 : 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: veryTightCard ? 8 : 9,
                                vertical: veryTightCard ? 5 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.18 : 0.06,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    slide.statsLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.sora(
                                      color: colors.textSecondary,
                                      fontSize: statsLabelSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: veryTightCard ? 3 : 4),
                                  Text(
                                    slide.statsValue,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.sora(
                                      color: colors.textPrimary,
                                      fontSize: statsValueSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: veryTightCard ? 8 : 10),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: veryTightCard ? 9 : 10,
                        vertical: veryTightCard ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        slide.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.sora(
                          color: accent,
                          fontSize: eyebrowSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: veryTightCard ? 0.6 : 0.9,
                        ),
                      ),
                    ),
                    SizedBox(height: veryTightCard ? 6 : 8),
                    Text(
                      slide.title,
                      maxLines: veryTightCard ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sora(
                        color: colors.textPrimary,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: tightCard ? -0.2 : -0.4,
                      ),
                    ),
                    SizedBox(height: veryTightCard ? 4 : 6),
                    Text(
                      slide.body,
                      maxLines: mergedCard ? 3 : (veryTightCard ? 3 : 2),
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sora(
                        color: colors.textSecondary,
                        fontSize: bodySize,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (mergedCard) ...[
                      SizedBox(height: compact ? 16 : 18),
                      Text(
                        'Why it fits NextFi',
                        style: AppFonts.sora(
                          color: colors.textPrimary,
                          fontSize: veryTightCard ? 15 : (tightCard ? 16 : 17),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A smoother start with cleaner choices, less clutter, and clear guidance before wallet setup.',
                        style: AppFonts.sora(
                          color: colors.textSecondary,
                          fontSize: veryTightCard
                              ? 12.5
                              : (tightCard ? 13 : 14),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 16),
                      for (final String bullet in slide.bullets)
                        Padding(
                          padding: EdgeInsets.only(bottom: compact ? 10 : 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: compact ? 22 : 24,
                                height: compact ? 22 : 24,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(
                                    alpha: isDark ? 0.22 : 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: compact ? 14 : 15,
                                  color: accent,
                                ),
                              ),
                              SizedBox(width: compact ? 10 : 12),
                              Expanded(
                                child: Text(
                                  bullet,
                                  style: AppFonts.sora(
                                    color: colors.textPrimary,
                                    fontSize: veryTightCard
                                        ? 12.5
                                        : (compact ? 13 : 14),
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: compact ? 4 : 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 14 : 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              accent.withValues(alpha: isDark ? 0.20 : 0.12),
                              accent.withValues(alpha: isDark ? 0.08 : 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.tips_and_updates_rounded,
                              color: accent,
                              size: compact ? 17 : 18,
                            ),
                            SizedBox(width: compact ? 8 : 10),
                            Expanded(
                              child: Text(
                                'Next, you can create a wallet or import an existing recovery phrase.',
                                style: AppFonts.sora(
                                  color: colors.textPrimary,
                                  fontSize: veryTightCard
                                      ? 11.8
                                      : (compact ? 12.3 : 13),
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.slideIndex,
    required this.slideCount,
    required this.colors,
    required this.isDark,
    required this.hasCover,
    required this.finishing,
    required this.onBack,
    required this.onNext,
  });

  final int slideIndex;
  final int slideCount;
  final AppColor colors;
  final bool isDark;
  final bool hasCover;
  final bool finishing;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(
          alpha: hasCover ? (isDark ? 0.68 : 0.80) : (isDark ? 0.74 : 0.90),
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (hasCover ? Colors.white : colors.border).withValues(
            alpha: hasCover ? (isDark ? 0.12 : 0.22) : 0.55,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(slideCount, (int index) {
              final bool active = slideIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == slideCount - 1 ? 0 : 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? colors.primary
                          : colors.border.withValues(
                              alpha: isDark ? 0.95 : 0.70,
                            ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _OnboardingArrowButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
                colors: colors,
                isDark: isDark,
                hasCover: hasCover,
                filled: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: finishing
                      ? Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: colors.primary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
              _OnboardingArrowButton(
                icon: Icons.arrow_forward_rounded,
                onTap: onNext,
                colors: colors,
                isDark: isDark,
                hasCover: hasCover,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingArrowButton extends StatelessWidget {
  const _OnboardingArrowButton({
    required this.icon,
    required this.onTap,
    required this.colors,
    required this.isDark,
    required this.hasCover,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final AppColor colors;
  final bool isDark;
  final bool hasCover;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color background = filled
        ? (enabled ? colors.primary : colors.primary.withValues(alpha: 0.45))
        : colors.surface.withValues(
            alpha: hasCover ? (isDark ? 0.56 : 0.78) : (isDark ? 0.62 : 0.88),
          );
    final Color iconColor = filled
        ? colors.onPrimary
        : (enabled ? colors.textPrimary : colors.textSecondary);

    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: (hasCover ? Colors.white : colors.border).withValues(
                    alpha: hasCover ? (isDark ? 0.12 : 0.24) : 0.65,
                  ),
                ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.colors,
    required this.child,
    required this.hasCover,
  });

  final AppColor colors;
  final Widget child;
  final bool hasCover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: hasCover ? 0.66 : 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (hasCover ? Colors.white : colors.border).withValues(
            alpha: hasCover ? 0.18 : 0.55,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
            stops: const <double>[0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accentSeed,
    required this.icon,
    required this.statsLabel,
    required this.statsValue,
    required this.bullets,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Color accentSeed;
  final IconData icon;
  final String statsLabel;
  final String statsValue;
  final List<String> bullets;
}

