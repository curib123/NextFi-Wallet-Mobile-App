// lib/Widgets/crypto_ui.dart
import 'dart:math' as math;
import 'dart:ui' show FontFeature; // <-- needed for FontFeature.tabularFigures
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
/// % change first -> last
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
          Icon(
            token.toUpperCase() == 'TRX' ? LucideIcons.sparkle : LucideIcons.banknote,
            size: 14,
            color: colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            token.toUpperCase(),
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
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
                          Text(
                            kRangeLabel[r]!,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected == r ? colors.primary : colors.textSecondary,
                            ),
                          ),
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
                Text(
                  "${changeUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                  style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(width: 6),
                Text(
                  rangeLabel,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
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

/// === Main sparkline chart (safe for flat series like USDT) =================
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

    double minVal = history.reduce(math.min);
    double maxVal = history.reduce(math.max);
    double lastY  = history.last;

    // If flat, pad slightly so axis ranges/intervals aren't zero.
    if (minVal == maxVal) {
      final pad = math.max(minVal.abs() * 0.01, 1e-6); // 1% or tiny epsilon
      minVal -= pad;
      maxVal += pad;
    }

    // Outer padding for visuals
    final minY = minVal * 0.995;
    final maxY = maxVal * 1.005;

    // Non-zero intervals
    final xInterval = history.length > 1 ? (history.length / 4).ceilToDouble() : 1.0;
    double yInterval = (maxY - minY) / 3.0;
    if (yInterval <= 0 || yInterval.isNaN || yInterval.isInfinite) {
      final mag = (maxVal.abs() + minVal.abs()) / 2.0;
      yInterval = _fallbackStep(mag);
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: xInterval, // never zero
                getTitlesWidget: (v, meta) => const SizedBox.shrink(),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: yInterval, // never zero
                getTitlesWidget: (v, meta) => Text(
                  _abbrMoney(fiatFmt, v),
                  style: TextStyle(
                    color: colors.textSecondary.withOpacity(0.9),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: minY,
          maxY: maxY,
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: lastY.clamp(minY, maxY),
              color: colors.primary.withOpacity(0.25),
              dashArray: const [6, 6],
              strokeWidth: 1.2,
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => " ${fiatFmt.format(lastY)} ",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  backgroundColor: colors.surface.withOpacity(0.8),
                ),
              ),
            ),
          ]),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map((s) => LineTooltipItem(
                fiatFmt.format(s.y),
                TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: [
                for (int i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i]),
              ],
              gradient: LinearGradient(
                colors: [changeColor, changeColor.withOpacity(0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                getDotPainter: (spot, percent, barData, index) {
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
        ),
      ),
    );
  }

  /// Abbreviate money values into K / M / B / T strings
  String _abbrMoney(NumberFormat fmt, double v) {
    final n = v.abs();
    if (n >= 1e12) return "${(v / 1e12).toStringAsFixed(2)}T";
    if (n >= 1e9)  return "${(v / 1e9).toStringAsFixed(2)}B";
    if (n >= 1e6)  return "${(v / 1e6).toStringAsFixed(2)}M";
    if (n >= 1e3)  return "${(v / 1e3).toStringAsFixed(2)}K";
    return v.toStringAsFixed(2);
  }

  // Pick a small positive step if range collapsed/invalid
  double _fallbackStep(double magnitude) {
    if (magnitude >= 100000) return 1000;
    if (magnitude >= 10000)  return 100;
    if (magnitude >= 1000)   return 10;
    if (magnitude >= 100)    return 1;
    if (magnitude >= 10)     return 0.5;
    if (magnitude >= 1)      return 0.1;
    if (magnitude >= 0.1)    return 0.01;
    if (magnitude >= 0.01)   return 0.001;
    return 0.0001;
  }
}

/// === Resources card ========================================================
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
    this.showGuide = true,
  });

  final bool loading;
  final String? errorText;
  final VoidCallback onRetry;
  final int energyUsed, energyLimit;
  final int bandwidthUsed, bandwidthLimit;
  final AppColor colors;
  final bool showGuide;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern();

    final energyRemain    = (energyLimit - energyUsed).clamp(0, energyLimit);
    final bandwidthRemain = (bandwidthLimit - bandwidthUsed).clamp(0, bandwidthLimit);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5,horizontal: 10),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: loading
          ? Row(
        children: [
          const SizedBox(width: 4),
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Text("Loading resources…", style: TextStyle(color: colors.textSecondary)),
        ],
      )
          : (errorText != null)
          ? Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(errorText!, style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Resources",
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: "What are Energy & Bandwidth?",
                icon: Icon(LucideIcons.info, size: 18, color: colors.primary),
                onPressed: () => _showFullExplanation(context, colors),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ResBar(
            icon: LucideIcons.zap, // Energy = zap
            label: "Energy",
            used: energyUsed,
            total: energyLimit,
            colors: colors,
            valueColor: Colors.green,
          ),
          const SizedBox(height: 8),
          _ResBar(
            icon: LucideIcons.activity, // Bandwidth = activity
            label: "Bandwidth",
            used: bandwidthUsed,
            total: bandwidthLimit,
            colors: colors,
            valueColor: Colors.blueAccent,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ChipStat(
                icon: LucideIcons.zap, // ⚡ Energy chip
                label: "Energy left",
                value: nf.format(energyRemain),
                bg: Colors.green.withOpacity(0.10),
                fg: Colors.green,
                border: Colors.green.withOpacity(0.30),
              ),
              const SizedBox(width: 8),
              _ChipStat(
                icon: LucideIcons.activity, // 🌐 Bandwidth chip
                label: "Bandwidth left",
                value: nf.format(bandwidthRemain),
                bg: Colors.blueAccent.withOpacity(0.10),
                fg: Colors.blueAccent,
                border: Colors.blueAccent.withOpacity(0.30),
              ),
            ],
          ),
          if (showGuide) ...[
            const SizedBox(height: 10),
            _GuideBlock(
              title: "Energy & Bandwidth",
              description:
              "• Energy: Consumed when executing smart contracts (e.g., sending USDT). "
                  "If Energy is insufficient, TRX is burned up to the fee_limit. "
                  "Gain more by freezing/staking TRX for Energy.\n\n"
                  "• Bandwidth: Covers transaction byte size (e.g., TRX transfers). "
                  "You get some free daily; if it runs out, TRX is burned. "
                  "Gain more by freezing/staking TRX for Bandwidth.",
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }

  void _showFullExplanation(BuildContext context, AppColor colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scroll) {
            return SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Understanding Energy & Bandwidth",
                    style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  Text("Energy",
                      style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    "• Required to execute smart contracts (e.g., USDT transfers).\n"
                        "• If Energy is insufficient, TRX is burned (up to fee_limit).\n"
                        "• Get more by freezing TRX for Energy or staking via TRON providers.",
                    style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  Text("Bandwidth",
                      style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    "• Covers the size of your transaction in bytes.\n"
                        "• Standard TRX transfers use Bandwidth only.\n"
                        "• If you run out of Bandwidth, TRX is burned.\n"
                        "• Get more by freezing TRX for Bandwidth or staking.",
                    style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  Text("How to get more?",
                      style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    "1) Freeze TRX (Energy or Bandwidth).\n"
                        "2) Use your free daily allocations.\n"
                        "3) Keep extra TRX for fees if resources are low.",
                    style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.check, color: Colors.white, size: 18),
                      label: const Text("Got it"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        elevation: 0,
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Progress bar for Energy/Bandwidth usage
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
    final nf = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              "${nf.format(remain)} / ${nf.format(total)}",
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
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

/// Small chip-style statistic (used in ResourcesCard bottom row)
class _ChipStat extends StatelessWidget {
  const _ChipStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guide block that shows an info icon and opens a modal sheet explanation.
class _GuideBlock extends StatelessWidget {
  const _GuideBlock({
    required this.title,
    required this.description,
    required this.colors,
  });

  final String title;
  final String description;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showGuideModal(context),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 16, color: colors.textSecondary.withOpacity(0.7)),
        ],
      ),
    );
  }

  void _showGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                  label: const Text("Got it"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    super.key,
    required this.token,
    required this.amountToken,
    required this.amountFiat,
    required this.colors,
    required this.numFmt,
    required this.fiatFmt,
    this.trailing, // optional widget (e.g., hide/show)
  });

  final String token;
  final double amountToken;
  final double amountFiat;
  final AppColor colors;
  final NumberFormat numFmt;
  final NumberFormat fiatFmt;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          // Left: icon + title
          Icon(LucideIcons.wallet2, size: 18, color: colors.primary),
          const SizedBox(width: 8),

          // Middle: token amount
          Expanded(
            child: Text(
              "${numFmt.format(amountToken)} ${token.toUpperCase()}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Right: fiat chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.primary.withOpacity(0.25)),
            ),
            child: Text(
              "≈ ${fiatFmt.format(amountFiat)}",
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),

          // Optional trailing
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/* ======================= Small local UI helpers from send screen ======================= */
class PctChip extends StatelessWidget {
  const PctChip({required this.label, required this.onTap, required this.colors});
  final String label;
  final VoidCallback onTap;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.primary.withOpacity(0.25)),
          ),
          child: Text(
            label,
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}

class ReviewRow extends StatelessWidget {
  const ReviewRow({required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}