import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/features/onboarding/presentation/viewmodels/onboarding_controller.dart';
import 'package:next_fi/features/wallet_creation/presentation/widgets/fintech_background.dart';

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
}

const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    eyebrow: 'SELF-CUSTODY',
    title: 'Your keys.\nYour wallet.',
    body: 'Your recovery phrase never leaves your device.',
    bullets: <String>[
      'Own your private keys',
      'PIN or biometric lock',
      'Send without third parties',
    ],
  ),
  _OnboardingSlide(
    eyebrow: 'PAYMENTS',
    title: 'Send & receive\nin seconds.',
    body: 'XLM and USDC, built for everyday use.',
    bullets: <String>[
      'Quick send & receive',
      'Review before confirming',
      'Mobile-first flows',
    ],
  ),
  _OnboardingSlide(
    eyebrow: 'P2P',
    title: 'Cash out\nanytime.',
    body: 'Convert crypto to cash through peer-to-peer trades.',
    bullets: <String>[
      'Simple trade flows',
      'Step-by-step review',
      'All in one wallet',
    ],
  ),
];

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
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    final int current = ref.read(onboardingControllerProvider).currentIndex;
    if (current == _slides.length - 1) {
      await _finish();
    } else {
      await _goToPage(current + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingControllerProvider);
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCover = onboarding.appCover?.hasUsableImage == true;
    final Color accent = colors.primary;

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
                        topBandFraction: .38,
                      ),
                    )
                  else
                    ColoredBox(color: colors.background),
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
                        stops: const <double>[0.0, 0.25, 1.0],
                        colors: <Color>[
                          colors.background.withValues(alpha: 0.08),
                          colors.background.withValues(alpha: 0.55),
                          colors.background.withValues(alpha: 0.98),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 720;
                final double h = constraints.maxWidth >= 720 ? 40.0 : 24.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    h,
                    compact ? 16 : 24,
                    h,
                    compact ? 20 : 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Header(
                        colors: colors,
                        onSkip: onboarding.finishing ? null : _finish,
                      ),
                      SizedBox(height: compact ? 32 : 52),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (int i) => ref
                              .read(onboardingControllerProvider.notifier)
                              .setCurrentIndex(i),
                          itemBuilder: (BuildContext context, int index) {
                            return _SlideContent(
                              slide: _slides[index],
                              accent: accent,
                              colors: colors,
                              isDark: isDark,
                              compact: compact,
                              isActive: index == onboarding.currentIndex,
                            );
                          },
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 36),
                      _Footer(
                        colors: colors,
                        accent: accent,
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

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.onSkip});

  static const String _appIconAsset = 'assets/icon/icon.png';

  final AppColor colors;
  final Future<void> Function()? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(_appIconAsset, fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        Text(
          'NextFi',
          style: AppFonts.title(
            color: colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (onSkip != null)
          GestureDetector(
            onTap: onSkip,
            child: Text(
              'Skip',
              style: AppFonts.body(
                color: colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.slide,
    required this.accent,
    required this.colors,
    required this.isDark,
    required this.compact,
    required this.isActive,
  });

  final _OnboardingSlide slide;
  final Color accent;
  final AppColor colors;
  final bool isDark;
  final bool compact;
  final bool isActive;
  static const String _appIconAsset = 'assets/icon/icon.png';

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 280),
      opacity: isActive ? 1.0 : 0.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 52 : 60,
            height: compact ? 52 : 60,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.24 : 0.16),
              ),
            ),
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: Image.asset(_appIconAsset, fit: BoxFit.contain),
          ),

          SizedBox(height: compact ? 28 : 40),

          Text(
            slide.eyebrow,
            style: AppFonts.label(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            slide.title,
            style: AppFonts.headline(
              color: colors.textPrimary,
              fontSize: compact ? 34 : 40,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: compact ? 14 : 18),

          Text(
            slide.body,
            style: AppFonts.body(
              color: colors.textSecondary,
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w400,
            ),
          ),

          SizedBox(height: compact ? 32 : 44),

          ...List<Widget>.generate(slide.bullets.length, (int i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < slide.bullets.length - 1 ? 16 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    slide.bullets[i],
                    style: AppFonts.body(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.colors,
    required this.accent,
    required this.currentIndex,
    required this.slideCount,
    required this.finishing,
    required this.onBack,
    required this.onNext,
  });

  final AppColor colors;
  final Color accent;
  final int currentIndex;
  final int slideCount;
  final bool finishing;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bool isLast = currentIndex == slideCount - 1;

    return Row(
      children: <Widget>[
        Row(
          children: List<Widget>.generate(slideCount, (int i) {
            final bool active = currentIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: active ? 22 : 6,
              height: 6,
              margin: EdgeInsets.only(right: i == slideCount - 1 ? 0 : 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active ? accent : colors.border,
              ),
            );
          }),
        ),

        const Spacer(),

        if (onBack != null) ...<Widget>[
          _IconBtn(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
            colors: colors,
          ),
          const SizedBox(width: 10),
        ],

        AppFilledButton(
          onPressed: finishing ? null : onNext,
          child: finishing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(isLast ? 'Get started' : 'Continue'),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: colors.onPrimary,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Icon(icon, color: colors.textSecondary, size: 20),
        ),
      ),
    );
  }
}
