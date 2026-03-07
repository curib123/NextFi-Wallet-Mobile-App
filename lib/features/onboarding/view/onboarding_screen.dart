import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/theme/app_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentIndex = 0;
  bool _finishing = false;

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
      body:
          'Move XLM and USDC with a cleaner flow built for everyday use.',
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
      body:
          'Buy, sell, and convert with a simpler peer-to-peer trade flow.',
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
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
        child: Stack(
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

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _OnboardingHeader(
                            colors: colors,
                            slideIndex: _currentIndex,
                            slideCount: _slides.length,
                            onSkip: _finishing ? null : _finish,
                          ),
                          SizedBox(height: compact ? 14 : 20),
                          SizedBox(
                            height: compact ? 196 : 236,
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
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compact ? 16 : 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _OnboardingDetailPanel(
                              key: ValueKey<int>(_currentIndex),
                              slide: slide,
                              colors: colors,
                              isDark: isDark,
                              compact: compact,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          _OnboardingFooter(
                            slideIndex: _currentIndex,
                            slideCount: _slides.length,
                            colors: colors,
                            isDark: isDark,
                            finishing: _finishing,
                            onBack: _currentIndex == 0 || _finishing
                                ? null
                                : () => _goToPage(_currentIndex - 1),
                            onNext: _finishing ? null : _next,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.colors,
    required this.slideIndex,
    required this.slideCount,
    required this.onSkip,
  });

  final AppColor colors;
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.account_balance_wallet_rounded, size: 16, color: colors.primary),
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
  });

  final _OnboardingSlide slide;
  final bool isActive;
  final bool isDark;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final Color accent = slide.accentSeed;
    final double scale = isActive ? 1.0 : 0.96;

    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      scale: scale,
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border.withValues(alpha: 0.52)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: isDark ? 0.28 : 0.16),
              colors.surface.withValues(alpha: isDark ? 0.92 : 0.96),
              colors.surface.withValues(alpha: isDark ? 0.78 : 0.90),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.48),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Icon(slide.icon, size: 22, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
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
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.statsValue,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sora(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                slide.eyebrow,
                style: AppFonts.sora(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slide.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.sora(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slide.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.sora(
                color: colors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingDetailPanel extends StatelessWidget {
  const _OnboardingDetailPanel({
    super.key,
    required this.slide,
    required this.colors,
    required this.isDark,
    required this.compact,
  });

  final _OnboardingSlide slide;
  final AppColor colors;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color accent = slide.accentSeed;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: isDark ? 0.62 : 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border.withValues(alpha: 0.50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Why it fits NextFi',
            style: AppFonts.sora(
              color: colors.textPrimary,
              fontSize: compact ? 16 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A smoother start with cleaner choices, less clutter, and clear guidance before wallet setup.',
            style: AppFonts.sora(
              color: colors.textSecondary,
              fontSize: compact ? 13.5 : 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          for (final String bullet in slide.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, size: 15, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      bullet,
                      style: AppFonts.sora(
                        color: colors.textPrimary,
                        fontSize: compact ? 13.5 : 14,
                        height: 1.5,
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
            padding: const EdgeInsets.all(16),
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
                Icon(Icons.tips_and_updates_rounded, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next, you can create a wallet or import an existing recovery phrase.',
                    style: AppFonts.sora(
                      color: colors.textPrimary,
                      fontSize: compact ? 12.5 : 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    required this.finishing,
    required this.onBack,
    required this.onNext,
  });

  final int slideIndex;
  final int slideCount;
  final AppColor colors;
  final bool isDark;
  final bool finishing;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stackedActions = constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: isDark ? 0.74 : 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.55)),
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
                children: List<Widget>.generate(
                  slideCount,
                  (int index) {
                    final bool active = slideIndex == index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == slideCount - 1 ? 0 : 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: active
                                ? colors.primary
                                : colors.border.withValues(alpha: isDark ? 0.95 : 0.70),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              stackedActions
                  ? Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: Icon(
                              slideIndex == slideCount - 1
                                  ? Icons.arrow_forward_rounded
                                  : Icons.navigate_next_rounded,
                            ),
                            label: Text(
                              finishing
                                  ? 'Preparing...'
                                  : slideIndex == slideCount - 1
                                      ? 'Continue to setup'
                                      : 'Next',
                              style: AppFonts.sora(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                color: colors.border.withValues(alpha: 0.65),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'Back',
                              style: AppFonts.sora(
                                color: onBack == null
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        SizedBox(
                          width: 100,
                          child: OutlinedButton(
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                color: colors.border.withValues(alpha: 0.65),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'Back',
                              style: AppFonts.sora(
                                color: onBack == null
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: Icon(
                              slideIndex == slideCount - 1
                                  ? Icons.arrow_forward_rounded
                                  : Icons.navigate_next_rounded,
                            ),
                            label: Text(
                              finishing
                                  ? 'Preparing...'
                                  : slideIndex == slideCount - 1
                                      ? 'Continue to setup'
                                      : 'Next',
                              style: AppFonts.sora(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.colors, required this.child});

  final AppColor colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
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
