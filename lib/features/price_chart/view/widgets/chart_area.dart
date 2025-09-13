// lib/features/price_chart/view/widgets/chart_area.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'empty_chart.dart';
import 'line_chart_painter.dart';

class ChartArea extends StatefulWidget {
  const ChartArea({
    super.key,
    required this.series,
    required this.positive,
    required this.onHoverIndex,
  });

  final List<double> series;
  final bool positive;
  final ValueChanged<int?> onHoverIndex;

  @override
  State<ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<ChartArea> with SingleTickerProviderStateMixin {
  int? _hoverIndex;
  bool _locked = false;

  late final AnimationController _anim;
  late Animation<double> _t;

  // For animating between series
  List<double>? _prevSeriesSnapshot;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _t = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);

    // Initial reveal
    _anim.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ChartArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If series changed, snapshot previous and animate to new
    if (!_sameSeries(oldWidget.series, widget.series)) {
      _prevSeriesSnapshot = List<double>.from(oldWidget.series);
      _locked = false;
      _hoverIndex = null;
      widget.onHoverIndex(null);
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final series = widget.series;

    if (series.length < 2 || !_isFiniteList(series)) {
      return const EmptyChart();
    }

    // Background subtle gradient to add depth
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            c.surface,
            c.surface.withOpacity(0.98),
            c.surface.withOpacity(0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          return MouseRegion(
            onHover: (ev) => _updateHover(ev.localPosition.dx, box.maxWidth, series.length),
            onExit: (_) {
              if (!_locked) _clearHover();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (d) => _updateHover(d.localPosition.dx, box.maxWidth, series.length),
              onPanUpdate: (d) => _updateHover(d.localPosition.dx, box.maxWidth, series.length),
              onPanEnd: (_) {
                if (!_locked) _clearHover();
              },
              onTapUp: (d) => _updateHover(d.localPosition.dx, box.maxWidth, series.length),
              onTapCancel: _clearHover,
              onLongPress: () => setState(() => _locked = !_locked),
              child: AnimatedBuilder(
                animation: _t,
                builder: (_, __) {
                  // Build points (with animation between previous & current series)
                  final current = _buildPoints(series, box.maxWidth, box.maxHeight);
                  final prev = _prevSeriesSnapshot != null
                      ? _buildPoints(_prevSeriesSnapshot!, box.maxWidth, box.maxHeight)
                      : null;
                  final points = _lerpPoints(prev, current, _t.value);

                  final hover = _hoverIndex != null
                      ? _hoverIndex!.clamp(0, points.length - 1)
                      : null;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Line + grid
                      CustomPaint(
                        painter: LineChartPainter(
                          points: points,
                          color: widget.positive ? c.primary : c.error,
                          gridColor: c.outlineVariant.withOpacity(0.25),
                          hoverIndex: hover,
                        ),
                        size: Size.infinite,
                      ),

                      // Crosshair + dot overlay
                      if (hover != null)
                        CustomPaint(
                          painter: _HoverOverlayPainter(
                            points: points,
                            index: hover,
                            color: widget.positive ? c.primary : c.error,
                            lineColor: c.outline.withOpacity(0.35),
                          ),
                          size: Size.infinite,
                        ),

                      // Value bubble
                      if (hover != null)
                        _ValueBubble(
                          x: points[hover].dx,
                          y: points[hover].dy,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          color: widget.positive ? c.primary : c.error,
                          background: c.surface.withOpacity(0.98),
                          textColor: c.onSurface,
                          value: series[hover],
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateHover(double dx, double width, int len) {
    final idx = ((dx / width) * (len - 1)).round().clamp(0, len - 1);
    if (_hoverIndex != idx) {
      setState(() => _hoverIndex = idx);
      widget.onHoverIndex(idx);
    }
  }

  void _clearHover() {
    if (_hoverIndex != null) {
      setState(() => _hoverIndex = null);
      widget.onHoverIndex(null);
    }
  }

  static bool _sameSeries(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    // Exact compare is ok for our case (data points are computed, not user-typed)
    return listEquals(a, b);
  }

  static bool _isFiniteList(List<double> xs) => xs.every((v) => !v.isNaN && !v.isInfinite);

  static List<Offset> _buildPoints(List<double> series, double w, double h) {
    final minV = series.reduce(math.min);
    final maxV = series.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-12 ? 1e-12 : (maxV - minV);

    final n = series.length;
    final dx = n > 1 ? w / (n - 1) : w;
    const padTop = 8.0;
    const padBottom = 10.0;
    final usableH = math.max(8.0, h - padTop - padBottom);

    return List<Offset>.generate(n, (i) {
      final x = dx * i;
      final t = (series[i] - minV) / range; // 0..1
      final y = padTop + (1.0 - t) * usableH;
      return Offset(x, y);
    });
  }

  static List<Offset> _lerpPoints(List<Offset>? a, List<Offset> b, double t) {
    if (a == null || a.length != b.length) return b;
    return List<Offset>.generate(b.length, (i) => Offset(
      _lerp(a[i].dx, b[i].dx, t),
      _lerp(a[i].dy, b[i].dy, t),
    ));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hover overlay painter (vertical line + dot with subtle glow)
// ─────────────────────────────────────────────────────────────────────────────
class _HoverOverlayPainter extends CustomPainter {
  _HoverOverlayPainter({
    required this.points,
    required this.index,
    required this.color,
    required this.lineColor,
  });

  final List<Offset> points;
  final int index;
  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = points[index];

    // Vertical line
    final vPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), vPaint);

    // Outer glow
    final glow = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(p, 8, glow);

    // Dot
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(p, 4.5, dot);

    // Inner core
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p, 1.6, core);
  }

  @override
  bool shouldRepaint(covariant _HoverOverlayPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.lineColor != lineColor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value bubble widget (kept in a widget so we can easily position/clip)
//
// It smartly keeps within chart bounds and adds a little elevation
// for a crisp, modern look.
// ─────────────────────────────────────────────────────────────────────────────
class _ValueBubble extends StatelessWidget {
  const _ValueBubble({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.background,
    required this.textColor,
    required this.value,
  });

  final double x, y;
  final double width, height;
  final Color color;
  final Color background;
  final Color textColor;
  final double value;

  @override
  Widget build(BuildContext context) {
    // Bubble size
    const bubbleW = 96.0;
    const bubbleH = 34.0;
    const radius = 10.0;
    const arrowH = 6.0;

    // Keep bubble inside chart bounds
    final left = (x - bubbleW / 2).clamp(0.0, math.max(0.0, width - bubbleW));
    final top = (y - bubbleH - 12).clamp(0.0, math.max(0.0, height - bubbleH - 12));

    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      width: bubbleW,
      height: bubbleH + arrowH,
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bubble body
            Container(
              width: bubbleW,
              height: bubbleH,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: color.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _fmt(value),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  fontSize: 13.5,
                ),
              ),
            ),
            // Arrow
            Positioned(
              left: bubbleW / 2 - 6,
              top: bubbleH - 1,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: background,
                    border: Border(
                      right: BorderSide(color: color.withOpacity(0.25)),
                      bottom: BorderSide(color: color.withOpacity(0.25)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 1000) return v.toStringAsFixed(0);
    if (abs >= 100) return v.toStringAsFixed(1);
    if (abs >= 1) return v.toStringAsFixed(3);
    if (abs >= 0.1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }
}
