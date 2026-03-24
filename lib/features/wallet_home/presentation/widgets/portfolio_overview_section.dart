import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/widgets/modal/reserve_balance.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_state.dart';
import 'package:next_fi/features/price_chart/presentation/widgets/chart_area.dart';

class PortfolioOverviewSection extends StatelessWidget {
  const PortfolioOverviewSection({
    super.key,
    required this.colors,
    required this.state,
    required this.currency,
    required this.liveTotalFiat,
    required this.reserveXlm,
    this.showHero = true,
    this.showReserveHelper = true,
    this.showActions = true,
    required this.onSend,
    required this.onReceive,
    required this.onScan,
    required this.onSwap,
    required this.onRetry,
    required this.onRangeChanged,
  });

  final AppColor colors;
  final PortfolioState state;
  final CurrencyVM currency;
  final double liveTotalFiat;
  final double reserveXlm;
  final bool showHero;
  final bool showReserveHelper;
  final bool showActions;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onScan;
  final VoidCallback onSwap;
  final Future<void> Function() onRetry;
  final ValueChanged<PortfolioRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final summary = state.data?.summary;
    final totalValue = summary?.totalValue ?? liveTotalFiat;
    final chart = state.data?.chart ?? const <PortfolioChartPoint>[];
    final series = chart.map((e) => e.totalValue).toList(growable: false);
    final labels = chart
        .map((e) => _labelFor(e.timestamp, state.selectedRange))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHero) ...[
          _hero(context, totalValue, summary),
          const SizedBox(height: 12),
        ],
        _ranges(),
        const SizedBox(height: 12),
        _card(_chart(summary, series, labels)),
        const SizedBox(height: 12),
        _card(_activity(state.data?.activity ?? const [])),
      ],
    );
  }

  Widget _hero(BuildContext context, double totalValue, PortfolioSummary? summary) {
    final change = summary?.absoluteChange ?? 0;
    final positive = change >= 0;
    final accent = positive ? colors.chartGreen : colors.chartRed;
    final isDark =
        ThemeData.estimateBrightnessForColor(colors.background) ==
        Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            isDark ? colors.surfaceRaised : const Color(0xFFF8FBFF),
            isDark ? colors.surfaceOverlay : const Color(0xFFFFFFFF),
          ],
        ),
        border: Border.all(
          color: isDark
              ? colors.border.withValues(alpha: 0.42)
              : colors.primary.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pill('Portfolio balance', colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      state.walletLabel?.trim().isNotEmpty == true
                          ? state.walletLabel!.trim()
                          : 'Active wallet',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shortAddress(state.activeWalletAddress),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Updated',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary == null
                          ? 'Waiting'
                          : DateFormat('MMM d, HH:mm').format(summary.lastUpdated),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.formatFiat(totalValue),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _pill(
                      '${positive ? '+' : ''}${(summary?.percentChange ?? 0).toStringAsFixed(2)}%',
                      accent,
                    ),
                    Text(
                      currency.formatSignedFiat(change),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showReserveHelper) ...[
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showReserveBalanceModal(
                context,
                colors: colors,
                money: NumberFormat.currency(
                  name: currency.fiatCode,
                  symbol: currency.fiatSymbol,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.lock,
                        color: colors.primary,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${reserveXlm.toStringAsFixed(1)} XLM kept for wallet fees',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      color: colors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (showActions) const SizedBox(height: 14),
          ] else if (showActions)
            const SizedBox(height: 16),
          if (showActions)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _action('Send', LucideIcons.arrowUpRight, onSend),
                _action('Receive', LucideIcons.arrowDownLeft, onReceive),
                _action('Scan', LucideIcons.scanLine, onScan),
                _action('Swap', LucideIcons.repeat2, onSwap),
              ],
            ),
        ],
      ),
    );
  }

  Widget _ranges() {
    const options = <(PortfolioRange, String)>[
      (PortfolioRange.h24, '24H'),
      (PortfolioRange.d7, '7D'),
      (PortfolioRange.d30, '30D'),
      (PortfolioRange.all, 'ALL'),
    ];
    return Row(
      children: options.map((entry) {
        final selected = entry.$1 == state.selectedRange;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onRangeChanged(entry.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected ? colors.primary : colors.surface,
                border: Border.all(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.5)
                      : colors.border.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                entry.$2,
                style: TextStyle(
                  color: selected ? colors.onPrimary : colors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _chart(PortfolioSummary? summary, List<double> series, List<String> labels) {
    if (state.loading && !state.hasData) return const _Skeleton(height: 220);
    if (state.error != null && !state.hasData) {
      return _status(
        LucideIcons.alertTriangle,
        'Portfolio unavailable',
        state.error!,
        true,
      );
    }
    if (state.isZeroBalance) {
      return _status(
        LucideIcons.wallet,
        'Zero balance',
        'Fund this wallet to start building a portfolio history.',
        false,
      );
    }
    if (state.isEmpty) {
      return _status(
        LucideIcons.lineChart,
        'No snapshots yet',
        'The first snapshot appears after a wallet sync event.',
        false,
      );
    }
    if (state.hasInsufficientData) {
      return _status(
        LucideIcons.activity,
        'Need more data',
        'Keep using this wallet to build a richer portfolio trend.',
        false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Performance'),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ChartArea(
            series: series,
            positive: (summary?.absoluteChange ?? 0) >= 0,
            onHoverIndex: (_) {},
            timeLabels: labels,
            accentColor:
                (summary?.absoluteChange ?? 0) >= 0
                    ? colors.chartGreen
                    : colors.chartRed,
          ),
        ),
      ],
    );
  }

  Widget _activity(List<PortfolioActivityItem> activity) {
    if (state.loading && !state.hasData) return const _Skeleton(height: 180);
    if (activity.isEmpty) {
      return _status(
        LucideIcons.history,
        'No recent portfolio activity',
        'Snapshots and balance changes will appear here.',
        false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recent activity'),
        const SizedBox(height: 12),
        ...activity.map((item) => _activityTile(item)),
      ],
    );
  }

  Widget _activityTile(PortfolioActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.chartGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.trendingUp,
                size: 18,
                color: colors.chartGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activityLabel(item.trigger),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy HH:mm').format(item.timestamp),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              currency.formatFiat(item.totalValue),
              style: TextStyle(
                color: colors.chartGreen,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.16)),
      ),
      child: child,
    );
  }

  Widget _status(IconData icon, String title, String subtitle, bool canRetry) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: colors.textSecondary),
        const SizedBox(height: 14),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (canRetry) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortAddress(String? value) {
    final address = (value ?? '').trim();
    if (address.length <= 12) return address.isEmpty ? 'No active wallet' : address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  String _labelFor(DateTime timestamp, PortfolioRange range) {
    switch (range) {
      case PortfolioRange.h24:
        return DateFormat('HH:mm').format(timestamp);
      case PortfolioRange.d7:
        return DateFormat('EEE').format(timestamp);
      case PortfolioRange.d30:
        return DateFormat('MMM d').format(timestamp);
      case PortfolioRange.all:
        return DateFormat('MMM yy').format(timestamp);
    }
  }

  String _activityLabel(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.appOpen:
        return 'App open snapshot';
      case WalletSnapshotTrigger.send:
        return 'Send completed';
      case WalletSnapshotTrigger.swap:
        return 'Swap completed';
      case WalletSnapshotTrigger.claim:
        return 'Claim completed';
      case WalletSnapshotTrigger.receiveDetected:
        return 'Incoming funds detected';
      case WalletSnapshotTrigger.walletSwitch:
        return 'Wallet switched';
      case WalletSnapshotTrigger.manualRefresh:
        return 'Manual refresh';
    }
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}
