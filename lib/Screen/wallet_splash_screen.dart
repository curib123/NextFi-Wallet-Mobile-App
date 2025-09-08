// lib/Screen/wallet_splash_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:next_fi/Helper/AppColor.dart';

class WalletSplashScreen extends StatefulWidget {
  const WalletSplashScreen({super.key});

  @override
  State<WalletSplashScreen> createState() => _WalletSplashScreenState();
}

class _WalletSplashScreenState extends State<WalletSplashScreen>
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

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background, now CLIPPED to the TOP area only.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _AuroraFintechPainter(
                    progress: _bgCtrl.value,
                    colors: colors,
                    topBandFraction: .45, // animate only in the top 45% height
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // Foreground content (STATIC: logo + title)
            Center(
              child: _GlassCard(
                colors: colors,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          _logoAsset,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ShimmerText(
                        "NextFI Wallet",
                        baseColor: colors.textPrimary,
                        highlightColor: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom subtitle (pinned)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  'Simple\u202F•\u202FUser Controlled\u202F•\u202FSecure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary.withOpacity(.95),
                    height: 1.35,
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.colors});
  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: child,
      ),
    );
  }
}

/// Shimmering title using an animated gradient shader.
class _ShimmerText extends StatefulWidget {
  const _ShimmerText(
      this.text, {
        required this.baseColor,
        required this.highlightColor,
      });

  final String text;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final w = MediaQuery.of(context).size.width;
        final dx = (w * 2) * _ctrl.value - w; // slide across
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor.withOpacity(.95),
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: GradientTranslation(dx),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        );
      },
    );
  }
}

class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);
  final double dx;

  @override
  vm.Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return vm.Matrix4.translationValues(dx, 0, 0);
  }
}

/// Fintech background with aurora blobs + soft grid + flowing line.
/// All animated elements are clipped to the TOP band so they don't sit behind the title.
/// Fintech background with full-screen grid, while aurora & chart stay in the top band.
class _AuroraFintechPainter extends CustomPainter {
  _AuroraFintechPainter({
    required this.progress,
    required this.colors,
    this.topBandFraction = .45, // 0..1 of screen height
  });

  final double progress; // 0..1
  final AppColor colors;
  final double topBandFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final double topH = (size.height * topBandFraction).clamp(0.0, size.height);

    // --- FULL-SCREEN GRID (draw first; no clipping) ---
    const step = 30.0;
    final drift = progress * step;
    final gridPaint = Paint()
      ..color = colors.primary.withOpacity(.05)
      ..strokeWidth = 1;

    // Vertical lines across entire height
    for (double x = -step + drift; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal lines across entire width
    for (double y = -step + drift; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // --- TOP-BAND ANIMATED LAYER (aurora blobs + flowing line) ---
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, topH));

    // Aurora blobs (additive)
    final blobPaint = Paint()..blendMode = BlendMode.plus;
    void blob(Offset c, double r, Color color, double opacity) {
      final radial = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      );
      blobPaint.shader =
          radial.createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, blobPaint);
    }

    final ph = progress * 2 * math.pi;
    final cx = size.width * (.3 + .2 * math.sin(ph * .8));
    final cy = topH * (.35 + .1 * math.cos(ph * 1.1));
    final cx2 = size.width * (.75 + .1 * math.cos(ph * 1.3));
    final cy2 = topH * (.75 + .08 * math.sin(ph * .9));

    blob(Offset(cx, cy), size.shortestSide * .40, colors.primary, .16);
    blob(Offset(cx2, cy2), size.shortestSide * .32, colors.success, .10);

    // Flowing price-like line
    final base = topH * .62;
    final p = Path()..moveTo(0, base);
    final amp1 = topH * .12;
    final amp2 = topH * .06;
    final wavelength = size.width * .95;

    for (double x = 0; x <= size.width; x += 3) {
      final t = (x / wavelength) * 2 * math.pi;
      final y = base +
          amp1 * math.sin(t + ph) +
          amp2 * math.sin(2 * t + ph * 1.7);
      p.lineTo(x, y.clamp(0, topH));
    }

    final halo = Paint()
      ..color = colors.primary.withOpacity(.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final stroke = Paint()
      ..color = colors.primary.withOpacity(.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(p, halo);
    canvas.drawPath(p, stroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraFintechPainter old) =>
      old.progress != progress ||
          old.colors != colors ||
          old.topBandFraction != topBandFraction;
}
