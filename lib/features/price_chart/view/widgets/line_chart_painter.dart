// lib/features/price_chart/view/widgets/line_chart_painter.dart
import 'package:flutter/material.dart';

class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.hoverIndex,
  });

  final List<Offset> points;
  final Color color;
  final Color gridColor;
  final int? hoverIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // grid
    final grid = Paint()..color = gridColor..strokeWidth = 1;
    const rows = 3;
    for (int i = 0; i <= rows; i++) {
      final y = size.height * (i / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // line
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, line);

    // fill
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.25), color.withOpacity(0.04), color.withOpacity(0.0)],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, Paint()..shader = shader);

    // hover marker
    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < points.length) {
      final p = points[hoverIndex!];
      canvas.drawCircle(p, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.points != points || old.color != color || old.gridColor != gridColor || old.hoverIndex != hoverIndex;
}
