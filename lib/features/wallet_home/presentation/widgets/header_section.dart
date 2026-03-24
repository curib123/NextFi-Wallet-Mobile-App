import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/modal/reserve_balance.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';

import 'live_counting_balance.dart';

class HeaderSection extends StatefulWidget {
  const HeaderSection({
    super.key,
    required this.colors,
    required this.currencyFmt,
    required this.loadingBalances,
    required this.totalFiat,
    required this.lastBalancesAt,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
    required this.livePulse,
    required this.incomingStrip,
    required this.selectedWindow,
    required this.onWindowChanged,
    required this.reserveXlm,
    required this.chartSeries,
    required this.chartDeltaFiat,
    this.animateTotal = false,
  });

  final AppColor colors;
  final NumberFormat currencyFmt;
  final bool loadingBalances;
  final double totalFiat;
  final DateTime? lastBalancesAt;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final AnimationController livePulse;
  final Widget incomingStrip;
  final bool animateTotal;
  final PriceWindow selectedWindow;
  final ValueChanged<PriceWindow> onWindowChanged;
  final double reserveXlm;
  final List<double> chartSeries;
  final double chartDeltaFiat;

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final isUp = widget.chartDeltaFiat >= 0;
    final chartColor = isUp ? widget.colors.success : widget.colors.error;
    final hasChartData =
        widget.chartSeries.where((v) => v.isFinite).length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: widget.colors.textPrimary.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.colors.surface,
                          widget.colors.surface.withValues(alpha: 0.98),
                          widget.colors.background.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasChartData)
                  Positioned(
                    left: -12,
                    right: -12,
                    top: 48,
                    bottom: 24,
                    child: IgnorePointer(
                      child: _BalanceTrendBackdrop(
                        series: widget.chartSeries,
                        color: chartColor,
                      ),
                    ),
                  ),
                if (hasChartData)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    height: 36,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              widget.colors.surface.withValues(alpha: 0.0),
                              widget.colors.surface.withValues(alpha: 0.08),
                              widget.colors.surface.withValues(alpha: 0.34),
                              widget.colors.surface.withValues(alpha: 0.72),
                            ],
                            stops: const [0.0, 0.42, 0.76, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.26, 0.78, 1.0],
                        colors: [
                          widget.colors.surface.withValues(alpha: 0.96),
                          widget.colors.surface.withValues(alpha: 0.58),
                          widget.colors.surface.withValues(
                            alpha: hasChartData ? 0.02 : 0.28,
                          ),
                          widget.colors.surface.withValues(alpha: 0.96),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TOTAL BALANCE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.colors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(
                                    () => _hideBalance = !_hideBalance,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _hideBalance
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 16,
                                      color: widget.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HeaderIconButton(
                            colors: widget.colors,
                            icon: LucideIcons.scanLine,
                            onTap: widget.onSwap,
                          ),
                          if (hasChartData) ...[
                            const SizedBox(width: 8),
                            _DeltaPill(
                              amount: widget.chartDeltaFiat,
                              fmt: widget.currencyFmt,
                              colors: widget.colors,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      LiveCountingBalance(
                        animate: widget.animateTotal,
                        hidden: _hideBalance,
                        targetValue: widget.totalFiat,
                        fmt: widget.currencyFmt,
                        baseColor: widget.colors.textPrimary,
                        upColor: widget.colors.success,
                        downColor: widget.colors.error,
                        loading: widget.loadingBalances,
                        pulse: widget.livePulse,
                        showTrendIcon: false,
                        forceBaseColor: true,
                        fontSize: 25,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.lastBalancesAt == null
                            ? 'Not synced yet'
                            : 'Updated ${DateFormat.jm().format(widget.lastBalancesAt!.toLocal())}',
                        style: TextStyle(
                          color: widget.colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(height: hasChartData ? 36 : 8),
                      if (hasChartData)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: PriceWindow.values.map((window) {
                            final isSelected = widget.selectedWindow == window;
                            return Padding(
                              padding: EdgeInsets.only(
                                left: window == PriceWindow.h24 ? 0 : 4,
                              ),
                              child: _RangePill(
                                label: _rangeLabel(window),
                                selected: isSelected,
                                colors: widget.colors,
                                onTap: () => widget.onWindowChanged(window),
                              ),
                            );
                          }).toList(),
                        ),
                      if (hasChartData) const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: _MicroInfo(
                            colors: widget.colors,
                            icon: LucideIcons.lock,
                            label:
                                '${widget.reserveXlm.toStringAsFixed(1)} XLM kept for wallet fees',
                            onTap: () {
                              showReserveBalanceModal(
                                context,
                                colors: widget.colors,
                                money: widget.currencyFmt,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActionTile(
                  colors: widget.colors,
                  icon: LucideIcons.send,
                  label: 'Send',
                  onTap: widget.onSend,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  colors: widget.colors,
                  icon: LucideIcons.download,
                  label: 'Receive',
                  onTap: widget.onReceive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  colors: widget.colors,
                  icon: LucideIcons.scanLine,
                  label: 'Swap',
                  onTap: widget.onSwap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        widget.incomingStrip,
      ],
    );
  }

  String _rangeLabel(PriceWindow window) {
    switch (window) {
      case PriceWindow.h24:
        return '1D';
      case PriceWindow.d7:
        return '1W';
      case PriceWindow.d30:
        return '1M';
      case PriceWindow.y1:
        return '1Y';
    }
  }
}

class _BalanceTrendBackdrop extends StatelessWidget {
  const _BalanceTrendBackdrop({required this.series, required this.color});

  final List<double> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      painter: _BalanceTrendPainter(series: series, color: color),
      size: Size.infinite,
    );
  }
}

class _BalanceTrendPainter extends CustomPainter {
  const _BalanceTrendPainter({required this.series, required this.color});

  final List<double> series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2 || size.isEmpty) return;

    var min = series.first;
    var max = series.first;
    for (final value in series) {
      if (!value.isFinite) continue;
      if (value < min) min = value;
      if (value > max) max = value;
    }

    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    const leftPad = 6.0;
    const rightPad = 6.0;
    const topPad = 8.0;
    const bottomPad = 10.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final points = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final x = leftPad + (chartWidth * i / (series.length - 1));
      final normalized = ((series[i] - min) / span).clamp(0.0, 1.0);
      final y = topPad + (chartHeight * (1 - normalized));
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          color.withValues(alpha: 0.34),
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.0),
        ],
        const [0.0, 0.56, 1.0],
      );
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(linePath, glowPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final endPoint = points.last;
    canvas.drawCircle(
      endPoint,
      4.2,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    canvas.drawCircle(endPoint, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BalanceTrendPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.color != color;
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.colors,
    required this.icon,
    required this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.border.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.amount,
    required this.fmt,
    required this.colors,
  });

  final double amount;
  final NumberFormat fmt;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final up = amount >= 0;
    final color = up ? colors.success : colors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${up ? '+' : '-'}${fmt.format(amount.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? colors.textPrimary : colors.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _MicroInfo extends StatelessWidget {
  const _MicroInfo({
    required this.colors,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              letterSpacing: -0.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: child,
              ),
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: colors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.92),
                      colors.primary,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: AppColor.of(context).onPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
