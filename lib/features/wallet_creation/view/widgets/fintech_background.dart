// lib/features/wallet_creation/view/widgets/fintech_background.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class FintechBackground extends StatelessWidget {
  const FintechBackground({
    super.key,
    required this.progress,
    required this.colors,
    required this.devicePixelRatio,
    this.topBandFraction = .55,
  });

  final double progress;
  final AppColor colors;
  final double devicePixelRatio;
  final double topBandFraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated gradient background
        Positioned.fill(
          child: CustomPaint(
            painter: _FintechBackgroundPainter(
              progress: progress,
              colors: colors,
              devicePixelRatio: devicePixelRatio,
              topBandFraction: topBandFraction,
            ),
          ),
        ),

        // Crypto visual elements overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _CryptoElementsPainter(
              progress: progress,
              colors: colors,
            ),
          ),
        ),
      ],
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

    // 1) Base radial gradient
    final radialRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radialGradient = RadialGradient(
      center: const Alignment(0.3, -0.4),
      radius: 1.2,
      colors: [
        colors.primary.withOpacity(.06),
        colors.surface.withOpacity(.0),
      ],
      stops: const [0.0, 1.0],
    );
    canvas.drawRect(radialRect, Paint()..shader = radialGradient.createShader(radialRect));

    // 2) Animated subtle grid texture
    final hiDpi = devicePixelRatio >= 2.75;
    const step = 35.0;
    final drift = progress * step;

    if (hiDpi) {
      final dotPaint = Paint()
        ..color = colors.primary.withOpacity(.02)
        ..style = PaintingStyle.fill;

      final dxDrift = drift;
      final dyDrift = drift * .5;

      for (double x = -step + dxDrift; x <= size.width; x += step) {
        for (double y = -step + dyDrift; y <= size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
        }
      }
    } else {
      final gridPaint = Paint()
        ..color = colors.primary.withOpacity(.015)
        ..strokeWidth = 1;

      for (double x = -step + drift; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = -step + drift; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 3) Top band with diagonal gradient
    canvas.save();
    final topRect = Rect.fromLTWH(0, 0, size.width, topH);
    canvas.clipRect(topRect);

    final diag = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary.withOpacity(.08),
          colors.primary.withOpacity(.03),
          Colors.transparent
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(topRect);
    canvas.drawRect(topRect, diag);

    // 4) Multiple flowing waves
    final ph = progress * 2 * math.pi;
    final base = topH * .58;

    // Wave 1 (main)
    final wave1Path = _createWavePath(
      size: size,
      topH: topH,
      base: base,
      phase: ph,
      amp1: topH * .15,
      amp2: topH * .07,
      wavelength: size.width * .9,
    );

    final wave1Area = Path.from(wave1Path)
      ..lineTo(size.width, topH)
      ..lineTo(0, topH)
      ..close();

    final area1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withOpacity(.06),
          colors.primary.withOpacity(.02),
          Colors.transparent
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(topRect);
    canvas.drawPath(wave1Area, area1Paint);

    // Wave 1 stroke
    final wave1Stroke = Paint()
      ..color = colors.primary.withOpacity(.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(wave1Path, wave1Stroke);

    // Wave 2 (secondary, offset)
    final wave2Path = _createWavePath(
      size: size,
      topH: topH,
      base: base + topH * .08,
      phase: ph * 1.3,
      amp1: topH * .10,
      amp2: topH * .05,
      wavelength: size.width * 1.1,
    );

    final wave2Stroke = Paint()
      ..color = colors.primary.withOpacity(.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(wave2Path, wave2Stroke);

    // 5) Animated nodes on main wave
    final wave1Points = _getWavePoints(
      size: size,
      topH: topH,
      base: base,
      phase: ph,
      amp1: topH * .15,
      amp2: topH * .07,
      wavelength: size.width * .9,
    );

    final nodePaint = Paint()
      ..color = colors.primary.withOpacity(.2)
      ..style = PaintingStyle.fill;

    final nodeGlowPaint = Paint()
      ..color = colors.primary.withOpacity(.04)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < wave1Points.length; i += 45) {
      // Glow
      canvas.drawCircle(wave1Points[i], 6, nodeGlowPaint);
      // Node
      canvas.drawCircle(wave1Points[i], 1.8, nodePaint);
    }

    canvas.restore();

    // 6) Bottom accent glow
    final bottomRect = Rect.fromLTWH(0, size.height * .7, size.width, size.height * .3);
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          colors.primary.withOpacity(.03),
        ],
        stops: const [0.0, 1.0],
      ).createShader(bottomRect);
    canvas.drawRect(bottomRect, bottomGlow);
  }

  Path _createWavePath({
    required Size size,
    required double topH,
    required double base,
    required double phase,
    required double amp1,
    required double amp2,
    required double wavelength,
  }) {
    final path = Path()..moveTo(0, base);
    for (double x = 0; x <= size.width; x += 2) {
      final t = (x / wavelength) * 2 * math.pi;
      final y = base + amp1 * math.sin(t + phase) + amp2 * math.sin(2 * t + phase * 1.7);
      final yy = y.clamp(0, topH).toDouble();
      path.lineTo(x, yy);
    }
    return path;
  }

  List<Offset> _getWavePoints({
    required Size size,
    required double topH,
    required double base,
    required double phase,
    required double amp1,
    required double amp2,
    required double wavelength,
  }) {
    final points = <Offset>[];
    for (double x = 0; x <= size.width; x += 2) {
      final t = (x / wavelength) * 2 * math.pi;
      final y = base + amp1 * math.sin(t + phase) + amp2 * math.sin(2 * t + phase * 1.7);
      final yy = y.clamp(0, topH).toDouble();
      points.add(Offset(x, yy));
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _FintechBackgroundPainter old) =>
      old.progress != progress ||
          old.colors != colors ||
          old.topBandFraction != topBandFraction ||
          old.devicePixelRatio != devicePixelRatio;
}

class _CryptoElementsPainter extends CustomPainter {
  _CryptoElementsPainter({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final AppColor colors;

  @override
  void paint(Canvas canvas, Size size) {
    final ph = progress * 2 * math.pi;

    // Floating hexagons
    _drawFloatingHexagon(canvas, size,
      x: size.width * 0.15,
      y: size.height * 0.25 + math.sin(ph * 0.7) * 15,
      hexSize: 40,
      rotation: progress * math.pi * 0.5,
    );

    _drawFloatingHexagon(canvas, size,
      x: size.width * 0.85,
      y: size.height * 0.35 + math.cos(ph * 0.5) * 20,
      hexSize: 30,
      rotation: -progress * math.pi * 0.3,
    );

    _drawFloatingHexagon(canvas, size,
      x: size.width * 0.1,
      y: size.height * 0.65 + math.sin(ph * 0.6) * 10,
      hexSize: 25,
      rotation: progress * math.pi * 0.4,
    );

    // Connection lines between elements
    _drawConnectionLines(canvas, size, ph);

    // Floating circular elements (like blockchain nodes)
    _drawBlockchainNodes(canvas, size, ph);
  }

  void _drawFloatingHexagon(Canvas canvas, Size size, {
    required double x,
    required double y,
    required double hexSize,
    required double rotation,
  }) {
    final path = Path();
    final center = Offset(x, y);
    final radius = hexSize / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3 * i) + rotation;
      final px = center.dx + radius * math.cos(angle);
      final py = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();

    // Glow
    final glowPaint = Paint()
      ..color = colors.primary.withOpacity(.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = colors.primary.withOpacity(.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);

    // Inner glow
    final innerGlowPaint = Paint()
      ..color = colors.primary.withOpacity(.015)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, innerGlowPaint);
  }

  void _drawConnectionLines(Canvas canvas, Size size, double phase) {
    final linePaint = Paint()
      ..color = colors.primary.withOpacity(.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = colors.primary.withOpacity(.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Diagonal connections
    final y1 = size.height * 0.25 + math.sin(phase * 0.7) * 15;
    final y2 = size.height * 0.35 + math.cos(phase * 0.5) * 20;

    _drawDashedLine(
      canvas,
      Offset(size.width * 0.15 + 20, y1),
      Offset(size.width * 0.85 - 15, y2),
      dashedPaint,
      dashWidth: 5,
      dashSpace: 3,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      {double dashWidth = 5, double dashSpace = 3}) {
    final path = Path();
    final totalDistance = (end - start).distance;
    final dashCount = (totalDistance / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final t1 = (i * (dashWidth + dashSpace)) / totalDistance;
      final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / totalDistance;

      if (t2 <= 1.0) {
        final p1 = Offset.lerp(start, end, t1)!;
        final p2 = Offset.lerp(start, end, t2)!;
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawBlockchainNodes(Canvas canvas, Size size, double phase) {
    final nodePaint = Paint()
      ..color = colors.primary.withOpacity(.12)
      ..style = PaintingStyle.fill;

    final nodeGlowPaint = Paint()
      ..color = colors.primary.withOpacity(.025)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final nodes = [
      Offset(size.width * 0.25, size.height * 0.72 + math.sin(phase * 0.8) * 8),
      Offset(size.width * 0.75, size.height * 0.68 + math.cos(phase * 0.9) * 12),
      Offset(size.width * 0.5, size.height * 0.8 + math.sin(phase * 0.6) * 6),
    ];

    for (final node in nodes) {
      // Outer glow
      canvas.drawCircle(node, 12, nodeGlowPaint);
      // Inner ring
      final ringPaint = Paint()
        ..color = colors.primary.withOpacity(.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(node, 6, ringPaint);
      // Center dot
      canvas.drawCircle(node, 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CryptoElementsPainter old) =>
      old.progress != progress || old.colors != colors;
}