import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

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

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                colors: colors,
                isDark: isDark,
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
                          colors.primary.withValues(alpha: 0.0),
                          colors.primary.withValues(alpha: 0.35),
                          colors.primary,
                          colors.primary.withValues(alpha: 0.35),
                          colors.primary.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.2, 0.5, 0.8, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 0.6,
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
    required this.colors,
    required this.isDark,
  });

  final double cutOutSize;
  final double borderRadius;
  final double strokeWidth;
  final double cornerLength;
  final AppColor colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.62 : 0.54);

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
      ..color = colors.primary
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = colors.primary.withValues(alpha: 0.34)
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
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.cutOutSize != cutOutSize ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colors.background != colors.background ||
        oldDelegate.colors.surface != colors.surface ||
        oldDelegate.colors.textPrimary != colors.textPrimary ||
        oldDelegate.colors.border != colors.border ||
        oldDelegate.colors.primary != colors.primary;
  }
}
