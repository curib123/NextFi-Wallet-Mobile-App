// lib/Screen/wallet_creation_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:next_fi/Components/CustomButton.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/import_wallet_screen.dart';
import 'package:next_fi/Screen/seed_phrase_screen.dart';

class WalletCreationScreen extends StatefulWidget {
  const WalletCreationScreen({
    super.key,
    this.isSplash = false,
  });

  /// When true, acts as a splash: hides action buttons (no ticker).
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
            // Animated background (top-band only)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _FintechBackgroundPainter(
                    progress: _bgCtrl.value,
                    colors: colors,
                    topBandFraction: .45,
                    devicePixelRatio: dpr,
                  ),
                  child: const SizedBox.expand(),
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
                          // subtle float + tilt based on progress
                          final t = _bgCtrl.value * 2 * math.pi;
                          final dy = math.sin(t) * 6;
                          final tilt = math.cos(t) * 0.02; // radians
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: Transform.rotate(
                              angle: tilt,
                              child: _GlassCard(
                                colors: colors,
                                child: Padding(
                                  padding:
                                  const EdgeInsets.fromLTRB(18, 22, 18, 18),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Conic gradient brand ring + logo (crisp, no glow)
                                      _ConicRingAvatar(
                                        size: 112,
                                        ringWidth: 3,
                                        asset: _logoAsset,
                                        imageSize: 96,
                                        baseColor: colors.primary,
                                        // spin ring slowly using same controller value
                                        rotationTurns: _bgCtrl.value,
                                      ),
                                      const SizedBox(height: 16),
                                      _ShimmerText(
                                        "NextFI Wallet",
                                        baseColor: colors.textPrimary,
                                        highlightColor: colors.primary,
                                      ),
                                      const SizedBox(height: 6),
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
                                      )
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

                  // Actions (hidden in splash mode)
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
          ],
        ),
      ),
    );
  }
}

/// Transparent card (no blur)
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.colors});
  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}

/// Brand avatar with a conic (sweep) gradient ring around the logo.
class _ConicRingAvatar extends StatelessWidget {
  const _ConicRingAvatar({
    required this.size,
    required this.ringWidth,
    required this.asset,
    required this.imageSize,
    required this.baseColor,
    this.rotationTurns = 0.0,
  });

  final double size;
  final double ringWidth;
  final String asset;
  final double imageSize;
  final Color baseColor;
  final double rotationTurns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ConicRingPainter(
              color: baseColor,
              strokeWidth: ringWidth,
              rotationTurns: rotationTurns,
            ),
          ),
          ClipOval(
            child: Image.asset(
              asset,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConicRingPainter extends CustomPainter {
  _ConicRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.rotationTurns,
  });

  final Color color;
  final double strokeWidth;
  final double rotationTurns;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Sweep gradient = conic gradient
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        color.withOpacity(.95),
        color.withOpacity(.25),
        color.withOpacity(.95),
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(rotationTurns * math.pi * 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawCircle(center, radius, paint);

    // Crisp inner hairline
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withOpacity(.15);
    canvas.drawCircle(center, radius - strokeWidth / 2 - 1, inner);
  }

  @override
  bool shouldRepaint(covariant _ConicRingPainter old) =>
      old.color != color ||
          old.strokeWidth != strokeWidth ||
          old.rotationTurns != rotationTurns;
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

/// Gradient translation helper (moves the gradient horizontally)
class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);
  final double dx;

  @override
  vm.Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return vm.Matrix4.translationValues(dx, 0, 0);
  }
}

/// Clean fintech background: micro-dot matrix on high-DPI, soft lines otherwise,
/// plus diagonal band and flowing line with faint area fill. (No glow.)
class _FintechBackgroundPainter extends CustomPainter {
  _FintechBackgroundPainter({
    required this.progress,
    required this.colors,
    required this.devicePixelRatio,
    this.topBandFraction = .45,
  });

  final double progress; // 0..1
  final AppColor colors;
  final double devicePixelRatio;
  final double topBandFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final double topH = (size.height * topBandFraction).clamp(0.0, size.height);

    // 1) Full-screen texture: dot matrix on hi-DPI, otherwise soft grid lines
    final hiDpi = devicePixelRatio >= 2.75;
    const step = 30.0;
    final drift = progress * step;

    if (hiDpi) {
      final dotPaint = Paint()
        ..color = colors.textSecondary.withOpacity(.08)
        ..style = PaintingStyle.fill;

      // diagonal drift feels nicer on dots
      final dxDrift = drift;
      final dyDrift = drift * .6;

      for (double x = -step + dxDrift; x <= size.width; x += step) {
        for (double y = -step + dyDrift; y <= size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
        }
      }
    } else {
      final gridPaint = Paint()
        ..color = colors.textSecondary.withOpacity(.06)
        ..strokeWidth = 1;

      for (double x = -step + drift; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = -step + drift; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 2) Top-band: subtle diagonal band/gradient (no glow)
    canvas.save();
    final topRect = Rect.fromLTWH(0, 0, size.width, topH);
    canvas.clipRect(topRect);

    final diag = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary.withOpacity(.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(topRect);
    canvas.drawRect(topRect, diag);

    // 3) Flowing “price” line with faint area fill
    final ph = progress * 2 * math.pi;
    final base = topH * .62;
    final p = Path()..moveTo(0, base);

    final amp1 = topH * .12;
    final amp2 = topH * .06;
    final wavelength = size.width * .95;

    final points = <Offset>[];
    for (double x = 0; x <= size.width; x += 3) {
      final t = (x / wavelength) * 2 * math.pi;
      final y =
          base + amp1 * math.sin(t + ph) + amp2 * math.sin(2 * t + ph * 1.7);
      final yy = y.clamp(0, topH).toDouble();
      p.lineTo(x, yy);
      points.add(Offset(x, yy));
    }

    // Area fill under the line (to bottom of top band)
    final area = Path.from(p)
      ..lineTo(size.width, topH)
      ..lineTo(0, topH)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withOpacity(.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(topRect);

    canvas.drawPath(area, areaPaint);

    // Line strokes (halo + hairline)
    final halo = Paint()
      ..color = colors.primary.withOpacity(.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final stroke = Paint()
      ..color = colors.primary.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(p, halo);
    canvas.drawPath(p, stroke);

    // Minimal nodes
    final nodePaint = Paint()
      ..color = colors.primary.withOpacity(.22)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i += 36) {
      canvas.drawCircle(points[i], 1.3, nodePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FintechBackgroundPainter old) =>
      old.progress != progress ||
          old.colors != colors ||
          old.topBandFraction != topBandFraction ||
          old.devicePixelRatio != devicePixelRatio;
}
