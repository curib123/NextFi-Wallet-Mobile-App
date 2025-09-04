// lib/Widgets/crypto_ui.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/AppColor.dart';

/// === Ranges ===============================================================
enum PriceRange { h24, d7, d30, y1 }
const Map<PriceRange, String> kRangeLabel = {
  PriceRange.h24: '24H',
  PriceRange.d7 : '7D',
  PriceRange.d30: '30D',
  PriceRange.y1 : '1Y',
};

/// === Helpers ==============================================================
double pctChangeFromSeries(List<double> series) {
  if (series.length < 2) return 0.0;
  final first = series.first, last = series.last;
  if (first <= 0) return 0.0;
  return ((last / first) - 1.0) * 100.0;
}

String abbrMoney(double v) {
  final n = v.abs();
  if (n >= 1e12) return "${(v / 1e12).toStringAsFixed(2)}T";
  if (n >= 1e9)  return "${(v / 1e9).toStringAsFixed(2)}B";
  if (n >= 1e6)  return "${(v / 1e6).toStringAsFixed(2)}M";
  if (n >= 1e3)  return "${(v / 1e3).toStringAsFixed(2)}K";
  return v.toStringAsFixed(2);
}

/// === Token pill ===========================================================
class TokenPill extends StatelessWidget {
  const TokenPill({super.key, required this.token, required this.colors});
  final String token;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(token.toUpperCase() == 'TRX' ? LucideIcons.sparkle : LucideIcons.banknote,
              size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text(token.toUpperCase(),
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// === Range segmented control =============================================
class RangeSegmented extends StatelessWidget {
  const RangeSegmented({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.colors,
    this.labels = const [PriceRange.h24, PriceRange.d7, PriceRange.d30, PriceRange.y1],
  });

  final PriceRange selected;
  final ValueChanged<PriceRange> onChanged;
  final AppColor colors;
  final List<PriceRange> labels;

  @override
  Widget build(BuildContext context) {
    IconData _icon(PriceRange r) => switch (r) {
      PriceRange.h24 => LucideIcons.timer,
      PriceRange.d7  => LucideIcons.calendar,
      PriceRange.d30 => LucideIcons.calendarDays,
      PriceRange.y1  => LucideIcons.clock4,
    };

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          for (final r in labels)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: selected == r ? colors.primary.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected == r ? colors.primary.withOpacity(0.35) : colors.primary.withOpacity(0.12),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onChanged(r),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(r), size: 16, color: selected == r ? colors.primary : colors.textSecondary),
                          const SizedBox(width: 6),
                          Text(kRangeLabel[r]!,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: selected == r ? colors.primary : colors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// === Price & change header =================================================
class PriceHeader extends StatelessWidget {
  const PriceHeader({
    super.key,
    required this.token,
    required this.oneTokenInFiat,
    required this.changePct,
    required this.colors,
    required this.fiatFmt,
    required this.rangeLabel,
  });

  final String token;
  final double oneTokenInFiat;
  final double changePct;
  final String rangeLabel;
  final AppColor colors;
  final NumberFormat fiatFmt;

  @override
  Widget build(BuildContext context) {
    final changeUp = changePct >= 0;
    final changeColor = changeUp ? Colors.green : Colors.red;
    final changeIcon = changeUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.wallet, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "1 ${token.toUpperCase()} ≈ ${fiatFmt.format(oneTokenInFiat)}",
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: changeColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(changeIcon, size: 14, color: changeColor),
                const SizedBox(width: 6),
                Text("${changeUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                    style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(width: 6),
                Text(rangeLabel,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// === Mini tag (used inside chart overlay) ==================================
class MiniTag extends StatelessWidget {
  const MiniTag({super.key, required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: color)),
        ],
      ),
    );
  }
}

/// === Main sparkline chart ==================================================
class MainLineChart extends StatelessWidget {
  const MainLineChart({
    super.key,
    required this.history,
    required this.changeColor,
    required this.fiatFmt,
    required this.colors,
  });

  final List<double> history;
  final Color changeColor;
  final NumberFormat fiatFmt;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withOpacity(0.08)),
        ),
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    final minY = history.reduce(math.min);
    final maxY = history.reduce(math.max);
    final lastY = history.last;

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: Stack(
        children: [
          LineChart(_chartData(history, minY, maxY, lastY)),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.badgeDollarSign, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    fiatFmt.format(lastY),
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: MiniTag(icon: LucideIcons.chevronsDown, label: "Min ${fiatFmt.format(minY)}", color: Colors.redAccent),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: MiniTag(icon: LucideIcons.chevronsUp, label: "Max ${fiatFmt.format(maxY)}", color: Colors.green),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(List<double> history, double minY, double maxY, double lastY) {
    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: (maxY - minY) / 3,
            getTitlesWidget: (v, _) => Text(
              abbrMoney(v),
              style: TextStyle(fontSize: 10.5),
            ),
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: minY * 0.995,
      maxY: maxY * 1.005,
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(
          y: lastY,
          color: colors.primary.withOpacity(0.25),
          dashArray: const [6, 6],
          strokeWidth: 1.2,
        ),
      ]),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
            NumberFormat.compactCurrency(symbol: NumberFormat.simpleCurrency(name: '').currencySymbol)
                .format(s.y),
            TextStyle(fontWeight: FontWeight.w700),
          ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          spots: [for (int i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i])],
          gradient:
          LinearGradient(colors: [changeColor, changeColor.withOpacity(0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [changeColor.withOpacity(0.18), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, p, bar, index) {
              final isLast = index == history.length - 1;
              return FlDotCirclePainter(
                radius: isLast ? 3.6 : 0,
                color: isLast ? changeColor : Colors.transparent,
                strokeWidth: isLast ? 2 : 0,
                strokeColor: Colors.white,
              );
            },
          ),
          barWidth: 3,
        ),
      ],
    );
  }
}

/// === Resources (Energy/Bandwidth) =========================================
class ResourcesCard extends StatelessWidget {
  const ResourcesCard({
    super.key,
    required this.loading,
    required this.errorText,
    required this.onRetry,
    required this.energyUsed,
    required this.energyLimit,
    required this.bandwidthUsed,
    required this.bandwidthLimit,
    required this.colors,
  });

  final bool loading;
  final String? errorText;
  final VoidCallback onRetry;
  final int energyUsed, energyLimit;
  final int bandwidthUsed, bandwidthLimit;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: loading
          ? Row(
        children: [
          const SizedBox(width: 4),
          SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
          const SizedBox(width: 12),
          Text("Loading resources…", style: TextStyle(color: colors.textSecondary)),
        ],
      )
          : (errorText != null)
          ? Row(
        children: [
          Icon(LucideIcons.alertCircle, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(errorText!, style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResBar(
            icon: LucideIcons.activity,
            label: "Energy",
            used: energyUsed,
            total: energyLimit,
            colors: colors,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          _ResBar(
            icon: LucideIcons.zap,
            label: "Bandwidth",
            used: bandwidthUsed,
            total: bandwidthLimit,
            colors: colors,
            valueColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}

class _ResBar extends StatelessWidget {
  const _ResBar({
    required this.icon,
    required this.label,
    required this.used,
    required this.total,
    required this.colors,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final int used;
  final int total;
  final AppColor colors;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final remain = math.max(0, total - used);
    final pct = total > 0 ? remain / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text("$remain / $total", style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.primary.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(valueColor),
          ),
        ),
      ],
    );
  }
}
