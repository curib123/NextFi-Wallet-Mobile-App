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
  const WalletCreationScreen({super.key});

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

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated fintech background (aurora + soft grid + flowing line)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => CustomPaint(
                  painter:
                  _AuroraFintechPainter(progress: _bgCtrl.value, colors: colors),
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
                                      // Round logo (asset clipped to a perfect circle)
                                      ClipOval(
                                        child: Image.asset(
                                          _logoAsset,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover, // circle crop
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Shimmer title
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

                  // Actions
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
                              builder: (_) => const SeedPhraseScreen()),
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
                              builder: (_) => const ImportWalletScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transparent card (no blur, clean border & soft shadow)
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.colors});
  final Widget child;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent, // no tint
        ),
        child: child,
      ),
    );
  }
}

/// Shimmering title using an animated gradient shader.
class _ShimmerText extends StatefulWidget {
  const _ShimmerText(this.text,
      {required this.baseColor, required this.highlightColor});
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
          child: const Text(
            "NextFI Wallet",
            textAlign: TextAlign.center,
            style: TextStyle(
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

/// Fintech background with aurora blobs + soft grid + flowing line.
/// No blur; clean transparency.
class _AuroraFintechPainter extends CustomPainter {
  _AuroraFintechPainter({required this.progress, required this.colors});
  final double progress; // 0..1
  final AppColor colors;

  @override
  void paint(Canvas canvas, Size size) {
    // --- Aurora blobs (light additive look) ---
    final blobPaint = Paint()..blendMode = BlendMode.plus;
    void blob(Offset c, double r, Color color, double opacity) {
      final radial = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      );
      blobPaint.shader = radial.createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, blobPaint);
    }

    final ph = progress * 2 * math.pi;
    final cx = size.width * (.3 + .2 * math.sin(ph * .8));
    final cy = size.height * (.35 + .1 * math.cos(ph * 1.1));
    final cx2 = size.width * (.75 + .1 * math.cos(ph * 1.3));
    final cy2 = size.height * (.7 + .08 * math.sin(ph * .9));

    blob(Offset(cx, cy), size.shortestSide * .45, colors.primary, .16);
    blob(Offset(cx2, cy2), size.shortestSide * .38, colors.success, .10);

    // --- Soft grid drift ---
    final step = 30.0;
    final drift = progress * step;
    final gridPaint = Paint()
      ..color = colors.primary.withOpacity(.05)
      ..strokeWidth = 1;

    for (double x = -step + drift; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -step + drift; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // --- Flowing price-like line (no blur, layered strokes) ---
    final base = size.height * .62;
    final p = Path()..moveTo(0, base);
    final amp1 = size.height * .07;
    final amp2 = size.height * .035;
    final wavelength = size.width * .95;
    final phase = ph;

    for (double x = 0; x <= size.width; x += 3) {
      final t = (x / wavelength) * 2 * math.pi;
      final y = base +
          amp1 * math.sin(t + phase) +
          amp2 * math.sin(2 * t + phase * 1.7);
      p.lineTo(x, y);
    }

    // Soft halo without blur
    final halo = Paint()
      ..color = colors.primary.withOpacity(.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Crisp line on top
    final stroke = Paint()
      ..color = colors.primary.withOpacity(.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(p, halo);
    canvas.drawPath(p, stroke);
  }

  @override
  bool shouldRepaint(covariant _AuroraFintechPainter old) =>
      old.progress != progress || old.colors != colors;
}
