import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../helper/colors/AppColor.dart';

class PageLoader extends StatelessWidget {
  const PageLoader({
    super.key,
    this.label,
    this.size = 25, // smaller by default
    this.speed = const Duration(milliseconds: 1400),
    this.color, // single color; defaults to AppColor.textSecondary
  });

  final String? label;
  final double size;
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

  // ── 2×2 grid ────────────────────────────────────────────────────────────────
  static const int _grid = 2; // 2×2
  static const List<List<int>> _moves = [
    // Ring clockwise on 2×2: indices (row-major): 0 1
    //                                       2 3
    // cycle: 0→1→3→2 (face turn)
    [0, 1, 3, 2],
    // then reverse (back) 0→2→3→1 for a smooth ping-pong feel
    [0, 2, 3, 1],
  ];

  final double Function() tProvider;
  final Color color;

  final Paint _paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  // layout
  final double _gapRatio = 0.10;      // a touch more space looks nicer on 2×2
  final double _cornerRatio = 0.12;   // slightly rounder corners
  double _strokeFor(Size size) => size.shortestSide * 0.08; // a bit thicker on 2×2

  double _ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = tProvider(); // 0..1 over whole cycle
    const n = _grid;
    final slots = n * n;

    // geometry
    final gap = size.shortestSide * _gapRatio;
    final totalGaps = gap * (n - 1);
    final tile = (size.shortestSide - totalGaps) / n;
    final r = Radius.circular(size.shortestSide * _cornerRatio);

    _paint
      ..color = color
      ..strokeWidth = _strokeFor(size);

    // Precompute grid centers
    final List<Offset> slotCenters = List.generate(slots, (i) {
      final row = i ~/ n;
      final col = i % n;
      final dx = col * (tile + gap) + tile / 2;
      final dy = row * (tile + gap) + tile / 2;
      return Offset(dx, dy);
    });

    // Phased moves
    final totalMoves = _moves.length;
    final phaseF = t * totalMoves;
    final completedMoves = phaseF.floor();
    final local = _ease(phaseF - completedMoves); // 0..1 within current move
    final currentMove = _moves[completedMoves % totalMoves];

    // slot->tile mapping after fully applying completed moves
    List<int> s2t = List.generate(slots, (i) => i);
    for (int m = 0; m < completedMoves; m++) {
      final cyc = _moves[m % totalMoves];
      _applyCycleInPlace(s2t, cyc);
    }

    // tileId -> current position
    final Map<int, Offset> tilePos = {};
    final movingSet = currentMove.toSet();

    // Fixed tiles
    for (int slot = 0; slot < slots; slot++) {
      final tileId = s2t[slot];
      if (!movingSet.contains(slot)) {
        tilePos[tileId] = slotCenters[slot];
      }
    }

    // Moving tiles (quadratic bezier arc for a subtle turn feel)
    for (int j = 0; j < currentMove.length; j++) {
      final fromSlot = currentMove[j];
      final toSlot = currentMove[(j + 1) % currentMove.length];

      final tileId = s2t[fromSlot];
      final p0 = slotCenters[fromSlot];
      final p1 = slotCenters[toSlot];

      final mid = Offset.lerp(p0, p1, 0.5)!;
      final dir = (p1 - p0);
      final norm =
      Offset(-dir.dy, dir.dx).scale(1 / (dir.distance + 1e-6), 1 / (dir.distance + 1e-6));
      final arcBump = tile * 0.14; // slightly stronger bump on 2×2
      final control = mid + norm * arcBump;

      final pos = _quadBezier(p0, control, p1, local);
      tilePos[tileId] = pos;
    }

    // Draw outlines; moving tiles get a tiny twist
    for (int tileId = 0; tileId < slots; tileId++) {
      final center = tilePos[tileId]!;
      final isMoving = _isTileMoving(tileId, s2t, currentMove);
      final twist = isMoving ? (math.sin(local * math.pi) * 0.16) : 0.0;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      if (twist != 0) canvas.rotate(twist);

      final rect = Rect.fromCenter(center: Offset.zero, width: tile, height: tile);
      final rr = RRect.fromRectAndRadius(rect, r);

      // main outline
      canvas.drawRRect(rr, _paint);

      // subtle inner border (comment out for super-clean look)
      final innerInset = tile * 0.12;
      final innerRect = Rect.fromCenter(
        center: Offset.zero,
        width: tile - innerInset,
        height: tile - innerInset,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(innerRect, r), _paint);

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
