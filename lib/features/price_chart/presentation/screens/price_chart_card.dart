import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_state.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_vm.dart';

import 'package:next_fi/features/price_chart/presentation/widgets/delta_pill.dart';
import 'package:next_fi/features/price_chart/presentation/widgets/range_tabs.dart';
import 'package:next_fi/features/price_chart/presentation/widgets/token_tabs.dart';
import 'package:next_fi/features/price_chart/presentation/widgets/chart_area.dart';

class PriceChartCard extends ConsumerStatefulWidget {
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
  final String token;
  final Color? accentColor;
  final ValueChanged<String>? onTokenChanged;

  @override
  ConsumerState<PriceChartCard> createState() => _PriceChartCardState();
}

class _PriceChartCardState extends ConsumerState<PriceChartCard> {
  late final PriceChartVM _vm;

  @override
  void initState() {
    super.initState();
    final currency = ref.read(currencyVmProvider);
    final assets = ref.read(assetVmProvider);
    _vm = PriceChartVM(currency, assets, initialAssetKey: widget.token);
  }

  @override
  void didUpdateWidget(covariant PriceChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.toUpperCase() != widget.token.toUpperCase()) {
      _vm.setAsset(widget.token);
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _PriceChartView(
        vm: _vm,
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
    required this.vm,
    required this.title,
    required this.compact,
    required this.isForDashboard,
    required this.accentColor,
    required this.onTokenChanged,
  });

  final PriceChartVM vm;
  final String title;
  final bool compact;
  final bool isForDashboard;
  final Color? accentColor;
  final ValueChanged<String>? onTokenChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final pad = compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
    final chartAccent = accentColor ?? (vm.isUp ? c.primary : c.error);

    final displayTitle = title == 'XLM Price' ? '${vm.assetCode} Price' : title;
    final availableAssets = vm.availableAssets;
    final activeAsset = vm.activeAsset;

    final displaySeries = vm.displaySeries;
    final timeLabels = vm.timeLabels;

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
                              assets: availableAssets,
                              token: activeAsset?.id ?? vm.selectedAssetKey,
                              onChanged: (assetKey) {
                                vm.setAsset(assetKey);
                                onTokenChanged?.call(assetKey);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${vm.range.longLabel} market view',
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
                          key: ValueKey(
                            '${vm.assetCode}_${shown}_${vm.fiatCode}',
                          ),
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

            AspectRatio(
              aspectRatio: compact ? 16 / 6 : 16 / 7,
              child: ChartArea(
                series: displaySeries,
                positive: vm.isUp,
                accentColor: chartAccent,

                onHoverIndex: vm.setHoverIndex,

                formatPrice: fmtPrice,

                currentPrice: vm.priceNow,

                timeLabels: timeLabels,

                showYAxisLabels: true,
                gridRows: 3,
              ),
            ),

            SizedBox(height: compact ? 8 : 12),

            RangeTabs(range: vm.range, onChanged: vm.setRange),
          ],
        ),
      ),
    );
  }
}
