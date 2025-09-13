// lib/features/price_chart/view/price_chart_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/features/ViewModel/currency_vm.dart';
import 'package:next_fi/features/price_chart/model/price_chart_state.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:provider/provider.dart';
import 'widgets/delta_pill.dart';
import 'widgets/range_tabs.dart';
import 'widgets/token_tabs.dart';
import 'widgets/chart_area.dart';

class PriceChartCard extends StatelessWidget {
  const PriceChartCard({
    super.key,
    this.title = 'XLM Price',
    this.compact = false,
    this.isForDashboard = false,
    this.token = 'XLM',
    this.onTokenChanged,
  });

  final String title;
  final bool compact;
  final bool isForDashboard;
  final String token; // "XLM" | "USDC"
  final ValueChanged<String>? onTokenChanged;

  @override
  Widget build(BuildContext context) {
    // local-scoped VM so multiple cards can live independently
    return ChangeNotifierProvider(
      create: (_) => PriceChartVM(
        context.read<CurrencyVM>(),
        initialToken: PriceTokenX.parse(token),
      ),
      child: _PriceChartView(
        title: title,
        compact: compact,
        isForDashboard: isForDashboard,
        onTokenChanged: onTokenChanged,
      ),
    );
  }
}

class _PriceChartView extends StatelessWidget {
  const _PriceChartView({
    required this.title,
    required this.compact,
    required this.isForDashboard,
    required this.onTokenChanged,
  });

  final String title;
  final bool compact;
  final bool isForDashboard;
  final ValueChanged<String>? onTokenChanged;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PriceChartVM>();
    final c  = Theme.of(context).colorScheme;
    final pad = compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);

    // if title was default "XLM Price", auto follow token
    final displayTitle = title == 'XLM Price' ? '${vm.token.code} Price' : title;
    final shown = vm.hoveredPrice ?? vm.priceNow;

    // if ALL range has too few points, fallback (same behavior as before)
    final data = (vm.range == PriceChartRange.all && vm.series.length < 2)
        ? (vm.token == PriceToken.usdc ? context.read<CurrencyVM>().usdcHistory365
        : context.read<CurrencyVM>().xlmHistory365)
        : vm.series;

    return Card(
      elevation: 0,
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
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
                                color: c.onSurface.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: compact ? 12 : 13,
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          '${fmtFiat(vm.fiatSym, shown)} ${vm.fiatCode}',
                          key: ValueKey('${vm.token.code}_${shown}_${vm.fiatCode}'),
                          style: TextStyle(
                            fontSize: compact ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
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

            // chart
            AspectRatio(
              aspectRatio: compact ? 16 / 6 : 16 / 7,
              child: ChartArea(
                series: data,
                positive: vm.isUp,
                onHoverIndex: vm.setHoverIndex,
              ),
            ),

            SizedBox(height: compact ? 8 : 12),

            // range
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
