import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConicRingAvatar extends StatelessWidget {
  const ConicRingAvatar({
    super.key,
    required this.size,
    required this.ringWidth,
    required this.asset,
    required this.imageSize,
    required this.baseColor,
    this.fillColor,
    this.imagePadding = 10,
    this.showInnerBorder = true,
    this.rotationTurns = 0.0,
  });

  final double size;
  final double ringWidth;
  final String asset;
  final double imageSize;
  final Color baseColor;
  final Color? fillColor;
  final double imagePadding;
  final bool showInnerBorder;
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
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fillColor ?? baseColor.withValues(alpha: .08),
              border: showInnerBorder
                  ? Border.all(
                      color: baseColor.withValues(alpha: .22),
                      width: 1.2,
                    )
                  : null,
            ),
            padding: EdgeInsets.all(imagePadding),
            child: ClipOval(
              child: Image.asset(
                asset,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
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

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        color.withValues(alpha: .95),
        color.withValues(alpha: .25),
        color.withValues(alpha: .95),
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(rotationTurns * math.pi * 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawCircle(center, radius, paint);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .15);

    canvas.drawCircle(center, radius - strokeWidth / 2 - 1, inner);
  }

  @override
  bool shouldRepaint(covariant _ConicRingPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.rotationTurns != rotationTurns;
}
