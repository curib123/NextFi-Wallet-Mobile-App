import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/features/onboarding/presentation/viewmodels/onboarding_controller.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/fintech_background.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController = PageController();
  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      eyebrow: 'SELF-CUSTODY',
      title: 'Your wallet stays in your hands.',
      body:
          'NextFi is non-custodial, so your wallet and recovery phrase stay with you.',
      accentSeed: AppColor.brandPrimary,
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
      accentSeed: AppColor.brandPrimary,
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
      accentSeed: AppColor.brandPrimary,
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
  void dispose() {
    _pageController.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(onboardingControllerProvider.notifier)
        .runFinish(widget.onFinish);
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
    final int currentIndex = ref
        .read(onboardingControllerProvider)
        .currentIndex;
    if (currentIndex == _slides.length - 1) {
      await _finish();
      return;
    }
    await _goToPage(currentIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingControllerProvider);
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCover = onboarding.appCover?.hasUsableImage == true;
    final slide = _slides[onboarding.currentIndex];

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (!hasCover)
                    AnimatedBuilder(
                      animation: _bgCtrl,
                      builder: (_, __) => FintechBackground(
                        progress: _bgCtrl.value,
                        colors: colors,
                        devicePixelRatio: MediaQuery.of(
                          context,
                        ).devicePixelRatio,
                        topBandFraction: .5,
                      ),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(color: colors.background),
                    ),
                  if (hasCover)
                    CachedNetworkImage(
                      imageUrl: onboarding.appCover!.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          colors.background.withValues(
                            alpha: hasCover ? 0.12 : 0.2,
                          ),
                          colors.surface.withValues(
                            alpha: hasCover
                                ? (isDark ? 0.18 : 0.14)
                                : (isDark ? 0.44 : 0.38),
                          ),
                          colors.background.withValues(
                            alpha: hasCover ? 0.58 : 0.92,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -60,
            child: _AmbientGlow(
              color: slide.accentSeed,
              size: 280,
              opacity: isDark ? 0.18 : 0.12,
            ),
          ),
          Positioned(
            right: -120,
            bottom: 100,
            child: _AmbientGlow(
              color: colors.textPrimary,
              size: 220,
              opacity: isDark ? 0.05 : 0.03,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 760;
                final double horizontal = constraints.maxWidth >= 720 ? 36 : 20;
                final double topSpacing = compact ? 10 : 18;
                final double cardSpacing = compact ? 20 : 28;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    topSpacing,
                    horizontal,
                    compact ? 18 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _OnboardingHeader(
                        colors: colors,
                        currentIndex: onboarding.currentIndex,
                        slideCount: _slides.length,
                        onSkip: onboarding.finishing ? null : _finish,
                      ),
                      SizedBox(height: cardSpacing),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (int index) {
                            ref
                                .read(onboardingControllerProvider.notifier)
                                .setCurrentIndex(index);
                          },
                          itemBuilder: (BuildContext context, int index) {
                            return AnimatedPadding(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.only(
                                right: index == _slides.length - 1 ? 0 : 12,
                              ),
                              child: _OnboardingHeroCard(
                                slide: _slides[index],
                                colors: colors,
                                isDark: isDark,
                                compact: compact,
                                isActive: index == onboarding.currentIndex,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      _OnboardingFooter(
                        colors: colors,
                        currentIndex: onboarding.currentIndex,
                        slideCount: _slides.length,
                        finishing: onboarding.finishing,
                        onBack:
                            onboarding.currentIndex == 0 || onboarding.finishing
                            ? null
                            : () => _goToPage(onboarding.currentIndex - 1),
                        onNext: onboarding.finishing ? null : _next,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.colors,
    required this.currentIndex,
    required this.slideCount,
    required this.onSkip,
  });

  final AppColor colors;
  final int currentIndex;
  final int slideCount;
  final Future<void> Function()? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'NextFi Wallet',
                    style: AppFonts.title(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${currentIndex + 1} of $slideCount',
                    style: AppFonts.body(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppTextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: Text(
            'Skip',
            style: AppFonts.label(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingHeroCard extends StatelessWidget {
  const _OnboardingHeroCard({
    required this.slide,
    required this.colors,
    required this.isDark,
    required this.compact,
    required this.isActive,
  });

  final _OnboardingSlide slide;
  final AppColor colors;
  final bool isDark;
  final bool compact;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color accent = slide.accentSeed;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: isActive ? 1 : 0.985,
      child: Container(
        padding: EdgeInsets.all(compact ? 22 : 28),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: isDark ? 0.94 : 0.98),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 1 : 0.8),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: isDark ? 0.06 : 0.04),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
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
                    width: compact ? 54 : 60,
                    height: compact ? 54 : 60,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      slide.icon,
                      color: accent,
                      size: compact ? 24 : 28,
                    ),
                  ),
                  const Spacer(),
                  _MetricPill(
                    label: slide.statsLabel,
                    value: slide.statsValue,
                    colors: colors,
                  ),
                ],
              ),
              SizedBox(height: compact ? 20 : 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  slide.eyebrow,
                  style: AppFonts.label(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  slide.title,
                  style: AppFonts.headline(
                    color: colors.textPrimary,
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  slide.body,
                  style: AppFonts.body(
                    color: colors.textSecondary,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: compact ? 22 : 28),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(compact ? 16 : 18),
                decoration: BoxDecoration(
                  color: colors.background.withValues(
                    alpha: isDark ? 0.70 : 0.65,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.border.withValues(alpha: isDark ? 1 : 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Why it fits NextFi',
                      style: AppFonts.title(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final String bullet in slide.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isDark ? 0.16 : 0.10,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: accent,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bullet,
                                style: AppFonts.body(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: accent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create a wallet or import an existing recovery phrase next.',
                        style: AppFonts.body(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 144),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.body(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.label(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.colors,
    required this.currentIndex,
    required this.slideCount,
    required this.finishing,
    required this.onBack,
    required this.onNext,
  });

  final AppColor colors;
  final int currentIndex;
  final int slideCount;
  final bool finishing;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bool isLast = currentIndex == slideCount - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(slideCount, (int index) {
              final bool active = currentIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == slideCount - 1 ? 0 : 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: active
                          ? colors.primary
                          : colors.border.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _FooterIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
                colors: colors,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFilledButton(
                  fullWidth: true,
                  onPressed: finishing ? null : onNext,
                  child: finishing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(isLast ? 'Get started' : 'Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: enabled ? colors.background : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Icon(
            icon,
            color: enabled ? colors.textPrimary : colors.textMuted,
            size: 22,
          ),
        ),
      ),
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
