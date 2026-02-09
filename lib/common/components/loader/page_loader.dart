import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../helper/colors/AppColor.dart';

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size = 25,
    this.speed = const Duration(milliseconds: 1400),
    this.color,
  });

  final String? label;
  final double size;
  final Duration speed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final c = color ?? colors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernFintechLoader(
              size: size,
              speed: speed,
              color: c,
            ),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(
                label!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Modern fintech loader with smooth animations
class ModernFintechLoader extends StatefulWidget {
  const ModernFintechLoader({
    super.key,
    this.size = 48,
    this.speed = const Duration(milliseconds: 1400),
    required this.color,
  });

  final double size;
  final Duration speed;
  final Color color;

  @override
  State<ModernFintechLoader> createState() => _ModernFintechLoaderState();
}

class _ModernFintechLoaderState extends State<ModernFintechLoader>
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
          painter: _FintechLoaderPainter(
            repaint: _ctrl,
            tProvider: () => _ctrl.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _FintechLoaderPainter extends CustomPainter {
  _FintechLoaderPainter({
    required Listenable repaint,
    required this.tProvider,
    required this.color,
  }) : super(repaint: repaint);

  final double Function() tProvider;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tProvider();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.35;

    // Draw 3 orbiting dots with smooth trails
    for (int i = 0; i < 3; i++) {
      final angle = (t * math.pi * 2) + (i * math.pi * 2 / 3);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      // Dot with soft gradient effect
      final dotRadius = size.shortestSide * 0.08;
      final opacity = 0.3 + (math.sin(t * math.pi * 2 + i) * 0.7).abs();

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotRadius * 0.5);

      canvas.drawCircle(Offset(x, y), dotRadius, paint);

      // Outer glow
      final glowPaint = Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotRadius * 1.5);

      canvas.drawCircle(Offset(x, y), dotRadius * 1.5, glowPaint);
    }

    // Center pulse circle
    final pulseRadius = radius * (0.15 + math.sin(t * math.pi * 2) * 0.1);
    final pulsePaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.02;

    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _FintechLoaderPainter oldDelegate) {
    return oldDelegate.color.value != color.value;
  }
}

// Legacy Rubiks Cube loader for backward compatibility
class RubiksCubeLoader extends StatefulWidget {
  const RubiksCubeLoader({
    super.key,
    this.size = 48,
    this.speed = const Duration(milliseconds: 1400),
    required this.color,
  });

  final double size;
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
    required this.color,
  }) : super(repaint: repaint);

  static const int _grid = 2;
  static const List<List<int>> _moves = [
    [0, 1, 3, 2],
    [0, 2, 3, 1],
  ];

  final double Function() tProvider;
  final Color color;

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  final double _gapRatio = 0.12;
  final double _cornerRatio = 0.20; // More rounded for softer look
  double _strokeFor(Size size) => size.shortestSide * 0.06; // Thinner stroke

  double _ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = tProvider();
    const n = _grid;
    final slots = n * n;

    final gap = size.shortestSide * _gapRatio;
    final totalGaps = gap * (n - 1);
    final tile = (size.shortestSide - totalGaps) / n;
    final r = Radius.circular(size.shortestSide * _cornerRatio);

    _paint
      ..color = color
      ..strokeWidth = _strokeFor(size);

    final List<Offset> slotCenters = List.generate(slots, (i) {
      final row = i ~/ n;
      final col = i % n;
      final dx = col * (tile + gap) + tile / 2;
      final dy = row * (tile + gap) + tile / 2;
      return Offset(dx, dy);
    });

    final totalMoves = _moves.length;
    final phaseF = t * totalMoves;
    final completedMoves = phaseF.floor();
    final local = _ease(phaseF - completedMoves);
    final currentMove = _moves[completedMoves % totalMoves];

    List<int> s2t = List.generate(slots, (i) => i);
    for (int m = 0; m < completedMoves; m++) {
      final cyc = _moves[m % totalMoves];
      _applyCycleInPlace(s2t, cyc);
    }

    final Map<int, Offset> tilePos = {};
    final movingSet = currentMove.toSet();

    for (int slot = 0; slot < slots; slot++) {
      final tileId = s2t[slot];
      if (!movingSet.contains(slot)) {
        tilePos[tileId] = slotCenters[slot];
      }
    }

    for (int j = 0; j < currentMove.length; j++) {
      final fromSlot = currentMove[j];
      final toSlot = currentMove[(j + 1) % currentMove.length];

      final tileId = s2t[fromSlot];
      final p0 = slotCenters[fromSlot];
      final p1 = slotCenters[toSlot];

      final mid = Offset.lerp(p0, p1, 0.5)!;
      final dir = (p1 - p0);
      final norm = Offset(-dir.dy, dir.dx)
          .scale(1 / (dir.distance + 1e-6), 1 / (dir.distance + 1e-6));
      final arcBump = tile * 0.12;
      final control = mid + norm * arcBump;

      final pos = _quadBezier(p0, control, p1, local);
      tilePos[tileId] = pos;
    }

    for (int tileId = 0; tileId < slots; tileId++) {
      final center = tilePos[tileId]!;
      final isMoving = _isTileMoving(tileId, s2t, currentMove);
      final twist = isMoving ? (math.sin(local * math.pi) * 0.10) : 0.0;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      if (twist != 0) canvas.rotate(twist);

      final rect =
      Rect.fromCenter(center: Offset.zero, width: tile, height: tile);
      final rr = RRect.fromRectAndRadius(rect, r);

      // Soft shadow effect
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.1)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(rr, shadowPaint);

      // Main outline with gradient effect
      canvas.drawRRect(rr, _paint);

      canvas.restore();
    }
  }

  void _applyCycleInPlace(List<int> s2t, List<int> cycle) {
    if (cycle.isEmpty) return;
    final first = s2t[cycle.first];
    for (int j = 0; j < cycle.length - 1; j++) {
      s2t[cycle[j]] = s2t[cycle[j + 1]];
    }
    s2t[cycle.last] = first;
  }

  bool _isTileMoving(int tileId, List<int> s2t, List<int> currentCycle) {
    for (final slot in currentCycle) {
      if (s2t[slot] == tileId) return true;
    }
    return false;
  }

  Offset _quadBezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _RubiksPainter oldDelegate) {
    return oldDelegate.color.value != color.value;
  }
}