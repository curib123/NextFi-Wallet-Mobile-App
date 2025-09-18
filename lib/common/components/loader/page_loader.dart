import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../helper/colors/AppColor.dart';

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size = 48, // smaller by default
    this.grid = 3,
    this.speed = const Duration(milliseconds: 1400),
    this.color, // single color; defaults to AppColor.textSecondary
  });

  final String? label;
  final double size;
  final int grid;
  final Duration speed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final c = color ?? colors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RubiksCubeLoader(
              size: size,
              grid: grid,
              speed: speed,
              color: c,
            ),
            if (label != null) ...[
              const SizedBox(height: 10),
              Text(
                label!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RubiksCubeLoader extends StatefulWidget {
  const RubiksCubeLoader({
    super.key,
    this.size = 48,
    this.grid = 3,
    this.speed = const Duration(milliseconds: 1400),
    required this.color,
  });

  final double size;
  final int grid;
  final Duration speed;
  final Color color;

  @override
  State<RubiksCubeLoader> createState() => _RubiksCubeLoaderState();
}

class _RubiksCubeLoaderState extends State<RubiksCubeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.speed)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RubiksPainter(
            repaint: _ctrl,
            tProvider: () => _ctrl.value,
            grid: widget.grid,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _RubiksPainter extends CustomPainter {
  _RubiksPainter({
    required Listenable repaint,
    required this.tProvider,
    required this.grid,
    required this.color,
  }) : super(repaint: repaint);

  final double Function() tProvider;
  final int grid;
  final Color color;

  final Paint _paint = Paint()..isAntiAlias = true;
  final double _gapRatio = 0.035;
  final double _cornerRatio = 0.08;
  final double _shadowOpacity = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tProvider(); // 0..1
    final n = grid.clamp(2, 8);
    final gap = size.shortestSide * _gapRatio;
    final totalGaps = gap * (n - 1);
    final tile = (size.shortestSide - totalGaps) / n;
    final r = Radius.circular(size.shortestSide * _cornerRatio);

    final shadowColor = const Color(0xFF000000).withOpacity(_shadowOpacity);
    double easeInOut(double x) => Curves.easeInOut.transform(x);

    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        final idx = row * n + col;
        final dx = col * (tile + gap);
        final dy = row * (tile + gap);

        final waveOffset = (row + col) / (n * 2.0);
        final tt = (t + waveOffset) % 1.0;
        final eased = easeInOut(tt);

        final scale = 0.9 + 0.1 * math.sin(2 * math.pi * eased);     // 0.9..1.0
        final rot = 0.12 * math.sin(2 * math.pi * (eased + 0.25));    // ±~7°
        final nudge = 0.6 * math.sin(2 * math.pi * (eased + idx / (n * n)));

        final cx = dx + tile / 2 + nudge;
        final cy = dy + tile / 2 - nudge;

        // Shadow
        _paint
          ..style = PaintingStyle.fill
          ..color = shadowColor;
        final shadowRect = Rect.fromCenter(
          center: Offset(cx, cy + 0.8),
          width: tile * scale,
          height: tile * scale,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(shadowRect, r), _paint);

        // Tile
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rot);
        canvas.scale(scale);

        _paint.color = color;
        final rect =
        Rect.fromCenter(center: Offset.zero, width: tile, height: tile);
        final rr = RRect.fromRectAndRadius(rect, r);
        canvas.drawRRect(rr, _paint);

        // subtle inner stroke
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF000000).withOpacity(0.06);
        canvas.drawRRect(rr, _paint);

        _paint.style = PaintingStyle.fill;
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RubiksPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.color.value != color.value;
  }
}
