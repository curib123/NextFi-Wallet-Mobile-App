import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FintechBackgroundPainter(
              progress: progress,
              colors: colors,
              devicePixelRatio: devicePixelRatio,
              topBandFraction: topBandFraction,
              isDark: isDark,
            ),
          ),
        ),

        Positioned.fill(
          child: CustomPaint(
            painter: _CryptoElementsPainter(progress: progress, colors: colors),
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
    required this.isDark,
  });

  final double progress;
  final AppColor colors;
  final double devicePixelRatio;
  final double topBandFraction;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final radialRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radialGradient = RadialGradient(
      center: const Alignment(0.3, -0.4),
      radius: 1.2,
      colors: [
        colors.primary.withValues(alpha: .06),
        colors.surface.withValues(alpha: .0),
      ],
      stops: const [0.0, 1.0],
    );
    canvas.drawRect(
      radialRect,
      Paint()..shader = radialGradient.createShader(radialRect),
    );

    final hiDpi = devicePixelRatio >= 2.75;
    const step = 35.0;
    final drift = progress * step;

    if (hiDpi) {
      final dotPaint = Paint()
        ..color = colors.primary.withValues(alpha: .02)
        ..style = PaintingStyle.fill;

      final dxDrift = drift;
      final dyDrift = drift * .5;

      for (double x = -step + dxDrift; x <= size.width; x += step) {
        for (double y = -step + dyDrift; y <= size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
        }
      }
    } else {
      final dotPaint = Paint()
        ..color = colors.primary.withValues(alpha: .018)
        ..style = PaintingStyle.fill;

      for (double x = -step + drift; x <= size.width; x += step) {
        for (double y = -step + (drift * .5); y <= size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
        }
      }
    }

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final diag = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary.withValues(alpha: .06),
          colors.primary.withValues(alpha: .025),
          colors.primary.withValues(alpha: .0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(fullRect);
    canvas.drawRect(fullRect, diag);

    final ph = progress * 2 * math.pi;
    final waveTopArea = size.height * topBandFraction;
    final base = waveTopArea * .58;

    final wave1Path = _createWavePath(
      size: size,
      topH: waveTopArea,
      base: base,
      phase: ph,
      amp1: waveTopArea * .15,
      amp2: waveTopArea * .07,
      wavelength: size.width * .9,
    );

    final wave1Area = Path.from(wave1Path)
      ..lineTo(size.width, waveTopArea)
      ..lineTo(0, waveTopArea)
      ..close();

    final waveRect = Rect.fromLTWH(0, 0, size.width, waveTopArea);
    final area1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.primary.withValues(alpha: .05),
          colors.primary.withValues(alpha: .018),
          colors.primary.withValues(alpha: .0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(waveRect);
    canvas.drawPath(wave1Area, area1Paint);

    final wave1Points = _getWavePoints(
      size: size,
      topH: waveTopArea,
      base: base,
      phase: ph,
      amp1: waveTopArea * .15,
      amp2: waveTopArea * .07,
      wavelength: size.width * .9,
    );

    final nodePaint = Paint()
      ..color = colors.primary.withValues(alpha: .2)
      ..style = PaintingStyle.fill;

    final nodeGlowPaint = Paint()
      ..color = colors.primary.withValues(alpha: .04)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < wave1Points.length; i += 45) {
      canvas.drawCircle(wave1Points[i], 6, nodeGlowPaint);
      canvas.drawCircle(wave1Points[i], 1.8, nodePaint);
    }

    final bottomRect = Rect.fromLTWH(
      0,
      size.height * .3,
      size.width,
      size.height * .7,
    );
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                colors.surface.withValues(alpha: .0),
                colors.primary.withValues(alpha: .03),
                colors.primary.withValues(alpha: .06),
                colors.surface.withValues(alpha: .22),
              ]
            : [
                colors.surface.withValues(alpha: .0),
                colors.primary.withValues(alpha: .03),
                colors.primary.withValues(alpha: .05),
                colors.primary.withValues(alpha: .09),
              ],
        stops: const [0.0, 0.3, 0.6, 1.0],
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
      final y =
          base +
          amp1 * math.sin(t + phase) +
          amp2 * math.sin(2 * t + phase * 1.7);
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
      final y =
          base +
          amp1 * math.sin(t + phase) +
          amp2 * math.sin(2 * t + phase * 1.7);
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
      old.devicePixelRatio != devicePixelRatio ||
      old.isDark != isDark;
}

class _CryptoElementsPainter extends CustomPainter {
  _CryptoElementsPainter({required this.progress, required this.colors});

  final double progress;
  final AppColor colors;

  @override
  void paint(Canvas canvas, Size size) {
    final ph = progress * 2 * math.pi;

    _drawFloatingHexagon(
      canvas,
      size,
      x: size.width * 0.15,
      y: size.height * 0.20 + math.sin(ph * 0.7) * 15,
      hexSize: 40,
      rotation: progress * math.pi * 0.5,
    );

    _drawFloatingHexagon(
      canvas,
      size,
      x: size.width * 0.85,
      y: size.height * 0.30 + math.cos(ph * 0.5) * 20,
      hexSize: 30,
      rotation: -progress * math.pi * 0.3,
    );

    _drawFloatingHexagon(
      canvas,
      size,
      x: size.width * 0.1,
      y: size.height * 0.50 + math.sin(ph * 0.6) * 10,
      hexSize: 25,
      rotation: progress * math.pi * 0.4,
    );

    _drawFloatingHexagon(
      canvas,
      size,
      x: size.width * 0.9,
      y: size.height * 0.65 + math.cos(ph * 0.8) * 12,
      hexSize: 35,
      rotation: progress * math.pi * 0.6,
    );

    _drawConnectionLines(canvas, size, ph);

    _drawBlockchainNodes(canvas, size, ph);
  }

  void _drawFloatingHexagon(
    Canvas canvas,
    Size size, {
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

    final glowPaint = Paint()
      ..color = colors.primary.withValues(alpha: .025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..color = colors.primary.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);

    final innerGlowPaint = Paint()
      ..color = colors.primary.withValues(alpha: .015)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, innerGlowPaint);
  }

  void _drawConnectionLines(Canvas canvas, Size size, double phase) {
    final dashedPaint = Paint()
      ..color = colors.primary.withValues(alpha: .06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final y1 = size.height * 0.20 + math.sin(phase * 0.7) * 15;
    final y2 = size.height * 0.30 + math.cos(phase * 0.5) * 20;
    final y3 = size.height * 0.50 + math.sin(phase * 0.6) * 10;
    final y4 = size.height * 0.65 + math.cos(phase * 0.8) * 12;

    _drawDashedLine(
      canvas,
      Offset(size.width * 0.15 + 20, y1),
      Offset(size.width * 0.85 - 15, y2),
      dashedPaint,
      dashWidth: 5,
      dashSpace: 3,
    );

    _drawDashedLine(
      canvas,
      Offset(size.width * 0.1 + 12, y3),
      Offset(size.width * 0.9 - 17, y4),
      dashedPaint,
      dashWidth: 4,
      dashSpace: 3,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
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
      ..color = colors.primary.withValues(alpha: .12)
      ..style = PaintingStyle.fill;

    final nodeGlowPaint = Paint()
      ..color = colors.primary.withValues(alpha: .025)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final nodes = [
      Offset(size.width * 0.25, size.height * 0.45 + math.sin(phase * 0.8) * 8),
      Offset(
        size.width * 0.75,
        size.height * 0.55 + math.cos(phase * 0.9) * 12,
      ),
      Offset(size.width * 0.5, size.height * 0.70 + math.sin(phase * 0.6) * 6),
      Offset(
        size.width * 0.35,
        size.height * 0.85 + math.cos(phase * 0.7) * 10,
      ),
      Offset(size.width * 0.65, size.height * 0.90 + math.sin(phase * 0.5) * 8),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, 12, nodeGlowPaint);
      final ringPaint = Paint()
        ..color = colors.primary.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(node, 6, ringPaint);
      canvas.drawCircle(node, 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CryptoElementsPainter old) =>
      old.progress != progress || old.colors != colors;
}
