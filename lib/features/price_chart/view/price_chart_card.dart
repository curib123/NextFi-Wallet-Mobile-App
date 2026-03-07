// lib/features/price_chart/view/price_chart_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/features/price_chart/model/price_chart_state.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';

import 'widgets/delta_pill.dart';
import 'widgets/range_tabs.dart';
import 'widgets/token_tabs.dart';
import 'widgets/chart_area.dart';

class PriceChartCard extends StatefulWidget {
  const PriceChartCard({
    super.key,
    this.title = 'XLM Price',
    this.compact = false,
    this.isForDashboard = false,
    this.token = 'XLM',
    this.accentColor,
    this.onTokenChanged,
  });

  final String title;
  final bool compact;
  final bool isForDashboard;
  final String token; // "XLM" | "USDC"
  final Color? accentColor;
  final ValueChanged<String>? onTokenChanged;

  @override
  State<PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends State<PriceChartCard> {
  late final PriceChartVM _vm;

  @override
  void initState() {
    super.initState();
    final currency = context.read<CurrencyVM>();
    _vm = PriceChartVM(
      currency,
      initialToken: PriceTokenX.parse(widget.token),
    );
  }

  @override
  void didUpdateWidget(covariant PriceChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.toUpperCase() != widget.token.toUpperCase()) {
      _vm.setToken(PriceTokenX.parse(widget.token));
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PriceChartVM>.value(
      value: _vm,
      child: _PriceChartView(
        title: widget.title,
        compact: widget.compact,
        isForDashboard: widget.isForDashboard,
        accentColor: widget.accentColor,
        onTokenChanged: widget.onTokenChanged,
      ),
    );
  }
}

class _PriceChartView extends StatelessWidget {
  const _PriceChartView({
    required this.title,
    required this.compact,
    required this.isForDashboard,
    required this.accentColor,
    required this.onTokenChanged,
  });

  final String title;
  final bool compact;
  final bool isForDashboard;
  final Color? accentColor;
  final ValueChanged<String>? onTokenChanged;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PriceChartVM>();
    final c = Theme.of(context).colorScheme;
    final pad = compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
    final chartAccent = accentColor ?? (vm.isUp ? c.primary : c.error);

    final displayTitle = title == 'XLM Price' ? '${vm.token.code} Price' : title;

    // Single source of truth for values on the chart (already FIAT)
    final displaySeries = vm.displaySeries;
    final timeLabels = vm.timeLabels;

    // Header value: hovered (fiat) else live-now (fiat)
    final shown = vm.hoveredPrice ?? vm.priceNow;

    String fmtPrice(double v) =>
        NumberFormat.simpleCurrency(name: vm.fiatCode).format(v);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.surface,
            c.surface.withValues(alpha: 0.98),
            chartAccent.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Padding(
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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
                              displayTitle,
                              style: TextStyle(
                                color: c.onSurface.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 12 : 13,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (isForDashboard)
                            TokenTabs(
                              token: vm.token.code,
                              onChanged: (t) {
                                vm.setToken(PriceTokenX.parse(t));
                                onTokenChanged?.call(t);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Live market view',
                        style: TextStyle(
                          color: c.onSurface.withValues(alpha: 0.48),
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 10.5 : 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          '${fmtPrice(shown)} ${vm.fiatCode}',
                          key: ValueKey('${vm.token.code}_${shown}_${vm.fiatCode}'),
                          style: TextStyle(
                            fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.w800,
                            color: c.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DeltaPill(pct: vm.pct, up: vm.isUp),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),

            // Chart
            AspectRatio(
              aspectRatio: compact ? 16 / 6 : 16 / 7,
              child: ChartArea(
                series: displaySeries,
                positive: vm.isUp,
                accentColor: chartAccent,

                // VM computes hoveredPrice from its own displaySeries
                onHoverIndex: vm.setHoverIndex,

                // Axis/bubble formatter (no extra conversion here)
                formatPrice: fmtPrice,

                // Sticky "current" (fiat) — VM already does live-first fallback
                currentPrice: vm.priceNow,

                // Time labels (hour/day/month per range)
                timeLabels: timeLabels,

                // Left-side labels
                showYAxisLabels: true,
                gridRows: 3,
              ),
            ),

            SizedBox(height: compact ? 8 : 12),

            // Range
            RangeTabs(
              range: vm.range,
              onChanged: vm.setRange,
            ),
          ],
        ),
      ),
    );
  }
}
