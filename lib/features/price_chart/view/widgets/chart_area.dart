// lib/features/price_chart/view/widgets/chart_area.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'empty_chart.dart';
import 'line_chart_painter.dart';

class ChartArea extends StatefulWidget {
  const ChartArea({super.key, required this.series, required this.positive, required this.onHoverIndex});
  final List<double> series;
  final bool positive;
  final ValueChanged<int?> onHoverIndex;

  @override
  State<ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<ChartArea> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final series = widget.series;

    if (series.length < 2 || !_isFiniteList(series)) {
      return const EmptyChart();
    }

    return LayoutBuilder(
      builder: (ctx, box) {
        final points = _buildPoints(series, box.maxWidth, box.maxHeight);
        final hover = _hoverIndex != null ? (_hoverIndex!.clamp(0, points.length - 1)) : null;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onPanUpdate: (d) => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onPanEnd: (_)    => _clearHover(),
          onTapUp:   (d)   => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onTapCancel: _clearHover,
          child: CustomPaint(
            painter: LineChartPainter(
              points: points,
              color: widget.positive ? c.primary : c.error,
              gridColor: c.outlineVariant.withOpacity(0.25),
              hoverIndex: hover,
            ),
          ),
        );
      },
    );
  }

  void _updateHover(double dx, double width, int len) {
    final idx = ((dx / width) * (len - 1)).round();
    setState(() => _hoverIndex = idx);
    widget.onHoverIndex(idx);
  }

  void _clearHover() {
    setState(() => _hoverIndex = null);
    widget.onHoverIndex(null);
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
}
