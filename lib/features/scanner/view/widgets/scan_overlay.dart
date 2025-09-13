import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A modern scanner overlay with a rounded square cutout and animated scan line.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({
    super.key,
    this.borderRadius = 20,
    this.strokeWidth = 3,
    this.cornerLength = 28,
    this.cutOutSizeFraction = 0.65, // fraction of the shortest side
  });

  final double borderRadius;
  final double strokeWidth;
  final double cornerLength;
  final double cutOutSizeFraction;

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final shortest = math.min(box.maxWidth, box.maxHeight);
      final cut = shortest * widget.cutOutSizeFraction;

      return Stack(
        children: [
          // Dim background with cutout
          CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: _OverlayPainter(
              cutOut: Size.square(cut),
              borderRadius: widget.borderRadius,
              strokeWidth: widget.strokeWidth,
              cornerLength: widget.cornerLength,
            ),
          ),
          // Animated scan line
          AnimatedBuilder(
            animation: _ctrl,
            builder: (ctx, _) {
              final lineY = (box.maxHeight - cut) / 2 + _ctrl.value * cut;
              return Positioned(
                left: (box.maxWidth - cut) / 2 + 8,
                right: (box.maxWidth - cut) / 2 + 8,
                top: lineY,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
                  ),
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.cutOut,
    required this.borderRadius,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final Size cutOut;
  final double borderRadius;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final cutRect = Rect.fromLTWH(
      (size.width - cutOut.width) / 2,
      (size.height - cutOut.height) / 2,
      cutOut.width,
      cutOut.height,
    );

    // Draw dim
    final r = RRect.fromRectAndRadius(cutRect, Radius.circular(borderRadius));
    final path = Path()..addRect(Offset.zero & size)..addRRect(r);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(path, overlayPaint);
    // Clear the cutout
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(r, clear);
    canvas.restore();

    // Corners
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(cutRect.topLeft, cutRect.topLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutRect.topLeft, cutRect.topLeft + Offset(0, cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(cutRect.topRight, cutRect.topRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cutRect.topRight, cutRect.topRight + Offset(0, cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(cutRect.bottomLeft, cutRect.bottomLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutRect.bottomLeft, cutRect.bottomLeft + Offset(0, -cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(cutRect.bottomRight, cutRect.bottomRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cutRect.bottomRight, cutRect.bottomRight + Offset(0, -cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => false;
}
