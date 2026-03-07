import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final Future<void> Function() onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _finishing = false;

  static const List<_OnboardingSlide> _slides = <_OnboardingSlide>[
    _OnboardingSlide(
      eyebrow: 'USER CONTROLLED',
      title: 'A Web3 wallet that keeps your funds in your hands.',
      body:
          'NextFi Wallet is non-custodial, so only you control your Stellar wallet, recovery phrase, and daily access.',
      icon: LucideIcons.shield,
      accent: _SlideAccent.primary,
      bullets: <String>[
        'Non-custodial wallet ownership',
        'Built for secure self-custody',
        'Fast XLM and USDC access',
      ],
    ),
    _OnboardingSlide(
      eyebrow: 'FAST PAYMENTS',
      title: 'Send, receive, and move money globally with less friction.',
      body:
          'Designed for OFWs and freelancers who need quicker digital payments, wallet transfers, and reliable access to USDC and XLM.',
      icon: LucideIcons.send,
      accent: _SlideAccent.success,
      bullets: <String>[
        'Global payments on Stellar',
        'XLM and USDC wallet support',
        'Clean wallet and payment flows',
      ],
    ),
    _OnboardingSlide(
      eyebrow: 'P2P FIAT ACCESS',
      title: 'Swap and convert through a peer-to-peer marketplace.',
      body:
          'Use the marketplace to buy, sell, and convert crypto to fiat while staying in control of your wallet activity and transaction choices.',
      icon: LucideIcons.arrowLeftRight,
      accent: _SlideAccent.info,
      bullets: <String>[
        'Swap between supported assets',
        'Convert through P2P trade flows',
        'Built for practical daily use',
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

  Future<void> _next() async {
    if (_currentIndex >= _slides.length - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              colors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
              colors.background,
              colors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: isDark ? 0.62 : 0.84),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            LucideIcons.wallet2,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NextFi Wallet',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (int index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return _OnboardingCard(
                        slide: _slides[index],
                        colors: colors,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    _slides.length,
                    (int index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: index == _currentIndex ? 28 : 8,
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? colors.primary
                            : colors.border.withValues(alpha: isDark ? 0.9 : 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: isDark ? 0.60 : 0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border.withValues(alpha: 0.55)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'Secure setup starts next',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a new wallet or import an existing recovery phrase after onboarding.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _finishing ? null : _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            _finishing
                                ? 'Preparing...'
                                : (_currentIndex == _slides.length - 1
                                    ? 'Continue to Wallet Setup'
                                    : 'Next'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
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
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.slide,
    required this.colors,
    required this.isDark,
  });

  final _OnboardingSlide slide;
  final AppColor colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = switch (slide.accent) {
      _SlideAccent.primary => colors.primary,
      _SlideAccent.success => colors.success,
      _SlideAccent.info => colors.info,
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.surface.withValues(alpha: isDark ? 0.78 : 0.90),
            colors.surface.withValues(alpha: isDark ? 0.52 : 0.72),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.26),
                  accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Icon(slide.icon, color: accent, size: 30),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              slide.eyebrow,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: isDark ? 0.44 : 0.52),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Why it fits NextFi',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final bullet in slide.bullets)
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
                              color: accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.check,
                              size: 13,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.bullets,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final _SlideAccent accent;
  final List<String> bullets;
}

enum _SlideAccent { primary, success, info }
