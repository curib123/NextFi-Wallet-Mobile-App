// lib/features/wallet_creation/view/widgets/fintech_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

class FintechBackground extends StatelessWidget {
  const FintechBackground({
    super.key,
    required this.progress,         // 0..1 (your AnimationController.value)
    required this.colors,
    required this.devicePixelRatio,
    this.topBandFraction = .45,
  });

  final double progress;
  final AppColor colors;
  final double devicePixelRatio;
  final double topBandFraction;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FintechBackgroundPainter(
        progress: progress,
        colors: colors,
        devicePixelRatio: devicePixelRatio,
        topBandFraction: topBandFraction,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FintechBackgroundPainter extends CustomPainter {
  _FintechBackgroundPainter({
    required this.progress,
    required this.colors,
    required this.devicePixelRatio,
    required this.topBandFraction,
  });

  final double progress;
  final AppColor colors;
  final double devicePixelRatio;
  final double topBandFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final double topH = (size.height * topBandFraction).clamp(0.0, size.height);

    // 1) Texture
    final hiDpi = devicePixelRatio >= 2.75;
    const step = 30.0;
    final drift = progress * step;

    if (hiDpi) {
      final dotPaint = Paint()
        ..color = colors.textSecondary.withOpacity(.08)
        ..style = PaintingStyle.fill;

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

    // 2) Top band gradient
    canvas.save();
    final topRect = Rect.fromLTWH(0, 0, size.width, topH);
    canvas.clipRect(topRect);

    final diag = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.primary.withOpacity(.08), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(topRect);
    canvas.drawRect(topRect, diag);

    // 3) Flowing line + area
    final ph = progress * 2 * math.pi;
    final base = topH * .62;
    final p = Path()..moveTo(0, base);

    final amp1 = topH * .12;
    final amp2 = topH * .06;
    final wavelength = size.width * .95;

    final points = <Offset>[];
    for (double x = 0; x <= size.width; x += 3) {
      final t = (x / wavelength) * 2 * math.pi;
      final y = base + amp1 * math.sin(t + ph) + amp2 * math.sin(2 * t + ph * 1.7);
      final yy = y.clamp(0, topH).toDouble();
      p.lineTo(x, yy);
      points.add(Offset(x, yy));
    }

    final area = Path.from(p)
      ..lineTo(size.width, topH)
      ..lineTo(0, topH)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.primary.withOpacity(.08), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(topRect);
    canvas.drawPath(area, areaPaint);

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
