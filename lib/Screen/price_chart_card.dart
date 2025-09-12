// lib/Components/price_chart_card.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Provider/CurrencyProvider.dart';

enum _ChartRange { h24, w1, m1, y1, all }

class PriceChartCard extends StatefulWidget {
  const PriceChartCard({
    super.key,
    this.title = 'XLM Price',
    this.compact = false,
    this.isForDashboard = false,
    this.token = 'XLM', // "XLM" or "USDC"
    this.onTokenChanged,
  });

  /// Title shown on the card header. If left as default ("XLM Price"),
  /// it will auto-switch to "<TOKEN> Price" when you toggle tokens.
  final String title;

  /// Compact paddings/heights.
  final bool compact;

  /// If true, renders XLM/USDC toggle chips in the header.
  final bool isForDashboard;

  /// Initial/controlled token: "XLM" or "USDC".
  final String token;

  /// Optional callback when user switches token (dashboard mode).
  final ValueChanged<String>? onTokenChanged;

  @override
  State<PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends State<PriceChartCard>
    with SingleTickerProviderStateMixin {
  _ChartRange _range = _ChartRange.h24;
  int? _hoverIndex;
  late String _token; // "XLM" or "USDC"

  late final AnimationController _fadeCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
    ..forward();

  @override
  void initState() {
    super.initState();
    _token = _normalizeToken(widget.token);
  }

  @override
  void didUpdateWidget(covariant PriceChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent changes token prop, sync our local state.
    final newTok = _normalizeToken(widget.token);
    if (newTok != _token) {
      setState(() => _token = newTok);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final pad = widget.compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);

    return Consumer<CurrencyProvider>(
      builder: (ctx, cur, _) {
        // Pick series based on token + range
        var data = _seriesFor(cur, _token, _range);
        if (data.length < 2 && _range == _ChartRange.all) {
          // fallback if ALL not available
          data = _token == 'USDC' ? cur.usdcHistory365 : cur.xlmHistory365;
        }

        final pct = _pctFor(cur, _token, _range);
        final up = pct >= 0;
        final fiat = cur.fiat.toUpperCase();
        final symbol = _fiatSymbol(fiat);

        final priceNow = _token == 'USDC' ? cur.usdcRate : cur.xlmRate;

        final hoveredPrice = (_hoverIndex != null &&
            _hoverIndex! >= 0 &&
            _hoverIndex! < data.length)
            ? (_token == 'USDC'
        // USDC series are already FIAT per 1 USDC
            ? data[_hoverIndex!]
        // XLM series are USDC-per-XLM → convert to FIAT
            : data[_hoverIndex!] * (cur.usdcRate <= 0 ? 1.0 : cur.usdcRate))
            : null;

        final displayedTitle =
        (widget.title == 'XLM Price') ? '$_token Price' : widget.title;

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: pad,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header: title + price + (optional token tabs) + delta ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayedTitle,
                                  style: TextStyle(
                                    color: c.onSurface.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                    fontSize: widget.compact ? 12 : 13,
                                  ),
                                ),
                              ),
                              if (widget.isForDashboard)
                                _TokenTabs(
                                  token: _token,
                                  onChanged: (t) {
                                    setState(() {
                                      _token = t;
                                      _hoverIndex = null;
                                    });
                                    widget.onTokenChanged?.call(t);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              '${_fmtFiat(symbol, hoveredPrice ?? priceNow)} $fiat',
                              key: ValueKey('${_token}_${hoveredPrice ?? priceNow}_$fiat'),
                              style: TextStyle(
                                fontSize: widget.compact ? 20 : 24,
                                fontWeight: FontWeight.w700,
                                color: c.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DeltaPill(pct: pct, up: up),
                  ],
                ),
                SizedBox(height: widget.compact ? 8 : 12),

                // ── Chart ───────────────────────────────────────────────────
                AspectRatio(
                  aspectRatio: widget.compact ? 16 / 6 : 16 / 7,
                  child: _ChartArea(
                    series: data,
                    positive: pct >= 0,
                    onHoverIndex: (i) => setState(() => _hoverIndex = i),
                  ),
                ),

                SizedBox(height: widget.compact ? 8 : 12),

                // ── Range Selector ──────────────────────────────────────────
                _RangeTabs(
                  range: _range,
                  onChanged: (r) {
                    setState(() {
                      _range = r;
                      _hoverIndex = null;
                    });
                    _fadeCtrl
                      ..reset()
                      ..forward();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _normalizeToken(String t) =>
      (t.trim().toUpperCase() == 'USDC') ? 'USDC' : 'XLM';

  List<double> _seriesFor(CurrencyProvider cur, String token, _ChartRange r) {
    final isUsdc = token == 'USDC';
    switch (r) {
      case _ChartRange.h24:
        return isUsdc ? cur.usdcHistory24h : cur.xlmHistory24h;
      case _ChartRange.w1:
        return isUsdc ? cur.usdcHistory7 : cur.xlmHistory7;
      case _ChartRange.m1:
        return isUsdc ? cur.usdcHistory30 : cur.xlmHistory30;
      case _ChartRange.y1:
        return isUsdc ? cur.usdcHistory365 : cur.xlmHistory365;
      case _ChartRange.all:
      // USDC has no real “all-time” volatility in this provider; reuse 1Y.
        return isUsdc ? cur.usdcHistory365 : cur.xlmHistoryAll;
    }
  }

  double _pctFor(CurrencyProvider cur, String token, _ChartRange r) {
    final isUsdc = token == 'USDC';
    if (isUsdc) {
      // USDC is a peg; provider keeps 0% for all windows.
      return 0.0;
    }
    switch (r) {
      case _ChartRange.h24:
        return cur.xlmPct24h;
      case _ChartRange.w1:
        return cur.xlmPct7d;
      case _ChartRange.m1:
        return cur.xlmPct30d;
      case _ChartRange.y1:
        return cur.xlmPct1y;
      case _ChartRange.all:
        return cur.xlmPctAll;
    }
  }

  static String _fmtFiat(String symbol, double v) {
    final abs = v.abs();
    NumberFormat nf;
    if (abs >= 1) {
      nf = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    } else if (abs >= 0.1) {
      nf = NumberFormat.currency(symbol: symbol, decimalDigits: 4);
    } else {
      nf = NumberFormat.currency(symbol: symbol, decimalDigits: 6);
    }
    return nf.format(v);
  }

  static String _fiatSymbol(String fiat) {
    switch (fiat) {
      case 'USD':
        return '\$';
      case 'PHP':
        return '₱';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return '';
    }
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.pct, required this.up});
  final double pct;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final clr = up ? c.primary : c.error;
    final bg = clr.withOpacity(0.12);
    final icon = up ? LucideIcons.trendingUp : LucideIcons.trendingDown;
    final text = (up ? '+' : '') + _fmtPct(pct);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: clr.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: clr),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: clr,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtPct(double v) {
    final abs = v.abs();
    final digits = abs >= 1 ? 2 : (abs >= 0.1 ? 3 : 4);
    return '${v.toStringAsFixed(digits)}%';
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.range, required this.onChanged});
  final _ChartRange range;
  final ValueChanged<_ChartRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final items = const [
      (_ChartRange.h24, '24H'),
      (_ChartRange.w1, '1W'),
      (_ChartRange.m1, '1M'),
      (_ChartRange.y1, '1Y'),
      (_ChartRange.all, 'ALL'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((e) {
          final selected = e.$1 == range;
          return Expanded(
            child: _SegmentButton(
              label: e.$2,
              selected: selected,
              onTap: () => onChanged(e.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TokenTabs extends StatelessWidget {
  const _TokenTabs({required this.token, required this.onChanged});
  final String token; // "XLM" or "USDC"
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final items = const ['XLM', 'USDC'];
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((t) {
          final selected = t == token;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => onChanged(t),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? c.primary.withOpacity(0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.2,
                    color: selected ? c.primary : c.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? c.primary : c.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

/// Lightweight custom line chart with gradient fill and drag tooltip.
/// For XLM: `series` is USDC-per-XLM (FIAT via usdcRate on hover).
/// For USDC: `series` is already FIAT-per-USDC.
class _ChartArea extends StatefulWidget {
  const _ChartArea({
    required this.series,
    required this.positive,
    required this.onHoverIndex,
  });

  final List<double> series;
  final bool positive;
  final ValueChanged<int?> onHoverIndex;

  @override
  State<_ChartArea> createState() => _ChartAreaState();
}

class _ChartAreaState extends State<_ChartArea> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final series = widget.series;

    if (series.length < 2 || !_isFiniteList(series)) {
      return _EmptyChart();
    }

    return LayoutBuilder(
      builder: (ctx, box) {
        final points = _buildPoints(series, box.maxWidth, box.maxHeight);
        final hover = _hoverIndex != null
            ? (_hoverIndex!.clamp(0, points.length - 1))
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onPanUpdate: (d) => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onPanEnd: (_) => _clearHover(),
          onTapUp: (d) => _updateHover(d.localPosition.dx, box.maxWidth, points.length),
          onTapCancel: _clearHover,
          child: CustomPaint(
            painter: _LineChartPainter(
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

  static bool _isFiniteList(List<double> xs) {
    for (final v in xs) {
      if (v.isNaN || v.isInfinite) return false;
    }
    return true;
  }

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

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
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

    // Grid
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const rows = 3;
    for (int i = 0; i <= rows; i++) {
      final y = size.height * (i / rows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Line
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

    // Fill
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.25),
        color.withOpacity(0.04),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Offset.zero & size);
    final fillPaint = Paint()..shader = shader;
    canvas.drawPath(fillPath, fillPaint);

    // Hover marker
    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < points.length) {
      final p = points[hoverIndex!];
      final marker = Paint()..color = color;
      canvas.drawCircle(p, 3.5, marker);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    return old.points != points ||
        old.color != color ||
        old.hoverIndex != hoverIndex ||
        old.gridColor != gridColor;
  }
}

class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withOpacity(0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        'No data',
        style: TextStyle(
          color: c.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
