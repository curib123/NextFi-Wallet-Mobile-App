import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScanOverlay extends StatefulWidget {
  const ScanOverlay({
    super.key,
    this.borderRadius = 24,
    this.strokeWidth = 4,
    this.cornerLength = 32,
    this.cutOutSizeFraction = 0.7,
  });

  final double borderRadius;
  final double strokeWidth;
  final double cornerLength;
  final double cutOutSizeFraction;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = math.min(constraints.maxWidth, constraints.maxHeight);
        final cutOutSize = shortest * widget.cutOutSizeFraction;

        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OverlayPainter(
                cutOutSize: cutOutSize,
                borderRadius: widget.borderRadius,
                strokeWidth: widget.strokeWidth,
                cornerLength: widget.cornerLength,
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final top = (constraints.maxHeight - cutOutSize) / 2;
                final left = (constraints.maxWidth - cutOutSize) / 2;
                final scanLineY = top + (_animation.value * cutOutSize);

                return Positioned(
                  left: left + 16,
                  right: left + 16,
                  top: scanLineY,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.8),
                          Colors.white,
                          Colors.white.withOpacity(0.8),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.2, 0.5, 0.8, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.cutOutSize,
    required this.borderRadius,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final double cutOutSize;
  final double borderRadius;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.65);

    final left = (size.width - cutOutSize) / 2;
    final top = (size.height - cutOutSize) / 2;
    final cutOutRect = Rect.fromLTWH(left, top, cutOutSize, cutOutSize);
    final cutOutRRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(cutOutRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, dimPaint);

    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    void drawCorner(Offset corner, double xSign, double ySign) {
      canvas.drawLine(
        corner,
        corner + Offset(cornerLength * xSign, 0),
        glowPaint,
      );
      canvas.drawLine(
        corner,
        corner + Offset(0, cornerLength * ySign),
        glowPaint,
      );
      canvas.drawLine(
        corner,
        corner + Offset(cornerLength * xSign, 0),
        cornerPaint,
      );
      canvas.drawLine(
        corner,
        corner + Offset(0, cornerLength * ySign),
        cornerPaint,
      );
    }

    final offset = borderRadius / 2;
    drawCorner(cutOutRect.topLeft + Offset(offset, offset), 1, 1);
    drawCorner(cutOutRect.topRight + Offset(-offset, offset), -1, 1);
    drawCorner(cutOutRect.bottomLeft + Offset(offset, -offset), 1, -1);
    drawCorner(cutOutRect.bottomRight + Offset(-offset, -offset), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => false;
}