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
    this.accentColor,

    /// Format a numeric value into display text (e.g., with fiat symbol).
    this.formatPrice,

    /// Sticky "now" price to tag at the last point (already in display fiat).
    this.currentPrice,

    /// Optional time labels (same length as series). If provided,
    /// they render as a small subtitle under the price in the bubble.
    this.timeLabels,

    this.showYAxisLabels = true,
    this.gridRows = 3,
  });

  final List<double> series;
  final bool positive;
  final ValueChanged<int?> onHoverIndex;
  final Color? accentColor;
  final String Function(double v)? formatPrice;
  final double? currentPrice;
  final List<String>? timeLabels;
  final bool showYAxisLabels;
  final int gridRows;

  @override
  State<ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<ChartArea> with SingleTickerProviderStateMixin {
  int? _hoverIndex;
  bool _locked = false;

  late final AnimationController _anim;
  late Animation<double> _t;

  List<double>? _prevSeriesSnapshot;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _t = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _anim.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ChartArea oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameSeries(oldWidget.series, widget.series)) {
      // Snapshot for transition
      _prevSeriesSnapshot = List<double>.from(oldWidget.series);

      // Reset internal hover (no setState; next frame/animation will rebuild)
      _locked = false;
      _hoverIndex = null;

      // Defer notifying VM about cleared hover to AFTER this build frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onHoverIndex(null);
      });

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
    final chartAccent = widget.accentColor ?? (widget.positive ? c.primary : c.error);

    // Fast guard
    if (widget.series.length < 2 || !_isFiniteList(widget.series)) {
      return const EmptyChart();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: [
            c.surface.withValues(alpha: 0.98),
            c.surface.withValues(alpha: 0.95),
            chartAccent.withValues(alpha: 0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          return MouseRegion(
            onHover: (ev) => _updateHover(ev.localPosition.dx, box.maxWidth, widget.series.length),
            onExit: (_) { if (!_locked) _clearHover(); },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (d) => _updateHover(d.localPosition.dx, box.maxWidth, widget.series.length),
              onPanUpdate: (d) => _updateHover(d.localPosition.dx, box.maxWidth, widget.series.length),
              onPanEnd: (_) { if (!_locked) _clearHover(); },

              // Clear hover after tap so header/sticky revert to "Now"
              onTapUp: (d) {
                _updateHover(d.localPosition.dx, box.maxWidth, widget.series.length);
                if (!_locked) _clearHover();
              },
              onTapCancel: _clearHover,

              onLongPress: () => setState(() => _locked = !_locked),
              child: AnimatedBuilder(
                animation: _t,
                builder: (_, __) {
                  // Inner guard (handles mid-frame empties)
                  final series = widget.series;
                  final hasData = series.length >= 2 && _isFiniteList(series) && box.maxWidth > 0 && box.maxHeight > 0;
                  if (!hasData) {
                    return const SizedBox.expand(child: EmptyChart());
                  }

                  final current = _buildPoints(series, box.maxWidth, box.maxHeight);
                  final prev = _prevSeriesSnapshot != null
                      ? _buildPoints(_prevSeriesSnapshot!, box.maxWidth, box.maxHeight)
                      : null;
                  final points = _lerpPoints(prev, current, _t.value);

                  if (points.length < 2) {
                    return const SizedBox.expand(child: EmptyChart());
                  }

                  final hover = _hoverIndex?.clamp(0, points.length - 1);

                  // Safe min/max for Y labels
                  final (minV, maxV) = _safeMinMax(series);

                  final rows = widget.gridRows.clamp(1, 6);
                  final labels = widget.showYAxisLabels
                      ? _buildYAxisLabelsLeft(
                    height: box.maxHeight,
                    minV: minV,
                    maxV: maxV,
                    rows: rows,
                    textColor: c.onSurface.withValues(alpha: 0.6),
                    bg: c.surface.withValues(alpha: 0.65),
                    border: c.outlineVariant.withValues(alpha: 0.20),
                  )
                      : const <Widget>[];

                  final showStickyNow = hover == null;
                  final nowValue = widget.currentPrice ?? series.last;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        painter: LineChartPainter(
                          points: points,
                          color: chartAccent,
                          gridColor: c.outlineVariant.withValues(alpha: 0.25),
                          hoverIndex: hover,
                        ),
                        size: Size.infinite,
                      ),

                      // Left-side Y labels
                      ...labels,

                      // Hover crosshair + dot
                      if (hover != null)
                        CustomPaint(
                          painter: _HoverOverlayPainter(
                            points: points,
                            index: hover,
                            color: chartAccent,
                            lineColor: c.outline.withValues(alpha: 0.35),
                            coreColor: c.onPrimary,
                          ),
                          size: Size.infinite,
                        ),

                      // Hover bubble (price + time label)
                      if (hover != null)
                        _ValueBubble(
                          x: points[hover].dx,
                          y: points[hover].dy,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          color: chartAccent,
                          background: c.surface.withValues(alpha: 0.98),
                          textColor: c.onSurface,
                          value: series[hover],
                          formatter: widget.formatPrice,
                          subText: (widget.timeLabels != null && widget.timeLabels!.length == series.length)
                              ? widget.timeLabels![hover]
                              : null,
                        ),

                      // Sticky “current” bubble at last point (when not hovering)
                      if (showStickyNow) ...[
                        CustomPaint(
                          painter: _DotOnlyPainter(
                            point: points.last,
                            color: chartAccent,
                            coreColor: c.onPrimary,
                          ),
                          size: Size.infinite,
                        ),
                        _ValueBubble(
                          x: points.last.dx,
                          y: points.last.dy,
                          width: box.maxWidth,
                          height: box.maxHeight,
                          color: chartAccent,
                          background: c.surface.withValues(alpha: 0.98),
                          textColor: c.onSurface,
                          value: nowValue,
                          formatter: widget.formatPrice,
                          subText: 'Now',
                        ),
                      ],
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
    if (len <= 0 || width <= 0) return;
    final idx = ((dx / width) * (len - 1)).round().clamp(0, math.max(0, len - 1));
    if (_hoverIndex != idx) {
      setState(() => _hoverIndex = idx.toInt());
      widget.onHoverIndex(idx.toInt());
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
    return listEquals(a, b);
  }

  static bool _isFiniteList(List<double> xs) => xs.isNotEmpty && xs.every((v) => !v.isNaN && !v.isInfinite);

  static (double, double) _safeMinMax(List<double> series) {
    if (series.isEmpty) return (0.0, 1.0);
    double minV = series.first, maxV = series.first;
    for (final v in series) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if ((maxV - minV).abs() < 1e-12) {
      maxV = minV + 1e-12; // avoid zero range
    }
    return (minV, maxV);
  }

  static List<Offset> _buildPoints(List<double> series, double w, double h) {
    if (series.isEmpty || w <= 0 || h <= 0) return const <Offset>[];

    final (minV, maxV) = _safeMinMax(series);
    final range = (maxV - minV);

    final n = series.length;
    final dx = n > 1 ? w / (n - 1) : w;
    const padTop = 8.0;
    const padBottom = 10.0;
    final usableH = math.max(8.0, h - padTop - padBottom);

    return List<Offset>.generate(n, (i) {
      final x = dx * i;
      final t = range == 0 ? 0.5 : (series[i] - minV) / range; // 0..1
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

  List<Widget> _buildYAxisLabelsLeft({
    required double height,
    required double minV,
    required double maxV,
    required int rows,
    required Color textColor,
    required Color bg,
    required Color border,
  }) {
    if (height <= 0) return const <Widget>[];
    final ticks = <Widget>[];
    for (int i = 0; i <= rows; i++) {
      final t = i / rows;
      final value = _lerpDouble(maxV, minV, t); // top→bottom
      final y = height * t;

      ticks.add(Positioned(
        left: 6,
        top: (y - 9).clamp(0.0, math.max(0.0, height - 18)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.formatPrice != null ? widget.formatPrice!(value) : _fmt(value),
            style: TextStyle(fontSize: 10.5, height: 1.0, color: textColor, fontWeight: FontWeight.w600),
          ),
        ),
      ));
    }
    return ticks;
  }

  static String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 1000) return v.toStringAsFixed(0);
    if (abs >= 100) return v.toStringAsFixed(1);
    if (abs >= 1) return v.toStringAsFixed(3);
    if (abs >= 0.1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────
class _HoverOverlayPainter extends CustomPainter {
  _HoverOverlayPainter({
    required this.points,
    required this.index,
    required this.color,
    required this.lineColor,
    required this.coreColor,
  });

  final List<Offset> points;
  final int index;
  final Color color;
  final Color lineColor;
  final Color coreColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final p = points[index];
    final vPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), vPaint);

    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(p, 8, glow);

    final dot = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;
    canvas.drawCircle(p, 4.5, dot);

    final core = Paint()..color = coreColor..style = PaintingStyle.fill;
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

class _DotOnlyPainter extends CustomPainter {
  _DotOnlyPainter({
    required this.point,
    required this.color,
    required this.coreColor,
  });
  final Offset point;
  final Color color;
  final Color coreColor;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(point, 7, glow);

    final dot = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;
    canvas.drawCircle(point, 4.0, dot);

    final core = Paint()..color = coreColor;
    canvas.drawCircle(point, 1.4, core);
  }

  @override
  bool shouldRepaint(covariant _DotOnlyPainter oldDelegate) {
    return oldDelegate.point != point || oldDelegate.color != color;
  }
}

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
    this.formatter,
    this.subText,
  });

  final double x, y;
  final double width, height;
  final Color color;
  final Color background;
  final Color textColor;
  final double value;
  final String Function(double v)? formatter;
  final String? subText;

  @override
  Widget build(BuildContext context) {
    const bubbleW = 116.0;
    const bubbleH = 44.0; // a bit taller for 2 lines
    const radius = 10.0;
    const arrowH = 6.0;

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
            Container(
              width: bubbleW,
              height: bubbleH,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: color.withValues(alpha: 0.25)),
                boxShadow: [BoxShadow(color: textColor.withValues(alpha: 0.06), blurRadius: 10, offset: Offset(0, 6))],
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatter != null ? formatter!(value) : _fmt(value),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, color: textColor, fontSize: 13.5, height: 1.0),
                  ),
                  if (subText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subText!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: textColor.withValues(alpha: 0.75), height: 1.0),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: bubbleW / 2 - 6,
              top: bubbleH - 1,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: background,
                    border: Border(
                      right: BorderSide(color: color.withValues(alpha: 0.25)),
                      bottom: BorderSide(color: color.withValues(alpha: 0.25)),
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
