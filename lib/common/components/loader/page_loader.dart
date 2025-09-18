import 'dart:math' as math;
import 'package:flutter/material.dart';

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size = 72,
    this.grid = 3,
    this.speed = const Duration(milliseconds: 1400),
    this.colors,
  });

  /// Optional text shown under the cube.
  final String? label;

  /// Square size of the loader.
  final double size;

  /// Grid dimension (3 => 3×3). Try 4 or 5 for denser effect.
  final int grid;

  /// One full animation loop.
  final Duration speed;

  /// Optional color palette override.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RubiksCubeLoader(
              size: size,
              grid: grid,
              speed: speed,
              colors: colors,
            ),
            if (text != null) ...[
              const SizedBox(height: 12),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
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
    this.size = 72,
    this.grid = 3,
    this.speed = const Duration(milliseconds: 1400),
    this.colors,
  });

  final double size;
  final int grid;
  final Duration speed;
  final List<Color>? colors;

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
    // RepaintBoundary + CustomPaint with repaint=listenable => very cheap
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RubiksPainter(
            repaint: _ctrl,
            tProvider: () => _ctrl.value,
            grid: widget.grid,
            palette: _resolvePalette(context, widget.colors),
          ),
        ),
      ),
    );
  }

  static List<Color> _resolvePalette(BuildContext ctx, List<Color>? override) {
    if (override != null && override.isNotEmpty) return override;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    // Softened classic Rubik’s palette
    return isDark
        ? [
      const Color(0xFFE84D4D), // red
      const Color(0xFFFFB547), // orange
      const Color(0xFFFFE569), // yellow
      const Color(0xFF5BE37B), // green
      const Color(0xFF6EC7FF), // blue
      const Color(0xFFEDEDED), // white/neutral
    ]
        : [
      const Color(0xFFD63939),
      const Color(0xFFF08C00),
      const Color(0xFFFAC000),
      const Color(0xFF2FBF71),
      const Color(0xFF2D9CDB),
      const Color(0xFFFAFAFA),
    ];
  }
}

class _RubiksPainter extends CustomPainter {
  _RubiksPainter({
    required Listenable repaint,
    required this.tProvider,
    required this.grid,
    required this.palette,
  }) : super(repaint: repaint);

  final double Function() tProvider;
  final int grid;
  final List<Color> palette;

  // Reused objects to avoid per-frame allocations.
  final Paint _paint = Paint()..isAntiAlias = true;
  final double _gapRatio = 0.03; // % of size as gap
  final double _cornerRatio = 0.06; // % of size as radius
  final double _shadowOpacityDark = 0.35;
  final double _shadowOpacityLight = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tProvider(); // 0..1
    final n = grid.clamp(2, 8); // sane bounds
    final gap = size.shortestSide * _gapRatio;
    final totalGaps = gap * (n - 1);
    final tile = (size.shortestSide - totalGaps) / n;
    final r = Radius.circular(size.shortestSide * _cornerRatio);

    // Shadow (single draw behind each tile)
    final isDark = _shadowOpacityDark > _shadowOpacityLight; // just using value
    final shadowColor = const Color(0xFF000000)
        .withOpacity(isDark ? _shadowOpacityDark : _shadowOpacityLight);

    // Precompute easing for speed (simple wrapper)
    double easeInOut(double x) => Curves.easeInOut.transform(x);

    // Draw tiles
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        final idx = row * n + col;
        final dx = col * (tile + gap);
        final dy = row * (tile + gap);

        // Stagger progress across a diagonal wave
        final waveOffset = (row + col) / (n * 2.0); // 0 .. ~0.5
        final tt = (t + waveOffset) % 1.0;
        final eased = easeInOut(tt);

        // Scale pulse (0.85..1.0)
        final scale = 0.85 + 0.15 * math.sin(2 * math.pi * eased);

        // Rotation wobble ~±10°
        final rot = 0.175 * math.sin(2 * math.pi * (eased + 0.25)); // radians

        // Tiny shuffle nudge
        final nudge = 0.9 * math.sin(2 * math.pi * (eased + idx / (n * n)));
        final cx = dx + tile / 2 + nudge;
        final cy = dy + tile / 2 - nudge;

        // Color cycling
        final colorIndex =
            ((eased * palette.length) + idx * 0.33).floor() % palette.length;
        final color = palette[colorIndex];

        // Shadow pass
        _paint.color = shadowColor;
        final shadowRect = Rect.fromCenter(
          center: Offset(cx, cy + 1), // slight down offset
          width: tile * scale,
          height: tile * scale,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(shadowRect, r),
          _paint,
        );

        // Tile pass
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rot);
        canvas.scale(scale);

        _paint.color = color;
        final rect = Rect.fromCenter(center: Offset.zero, width: tile, height: tile);
        final rr = RRect.fromRectAndRadius(rect, r);
        canvas.drawRRect(rr, _paint);

        // Subtle inner stroke for definition (no extra widgets)
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF000000).withOpacity(0.06);
        canvas.drawRRect(rr, _paint);
        _paint.style = PaintingStyle.fill; // reset

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RubiksPainter oldDelegate) {
    // Repaints only when animation tick/palette/grid change.
    return oldDelegate.grid != grid || oldDelegate.palette != palette;
  }
}
