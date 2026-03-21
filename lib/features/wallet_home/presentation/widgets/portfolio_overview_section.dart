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
    this.showReserveHelper = true,
    this.showActions = true,
    required this.onSend,
    required this.onReceive,
    required this.onScan,
    required this.onSwap,
    required this.onP2P,
    required this.onRetry,
    required this.onRangeChanged,
  });

  final AppColor colors;
  final PortfolioState state;
  final CurrencyVM currency;
  final double liveTotalFiat;
  final double reserveXlm;
  final bool showReserveHelper;
  final bool showActions;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onScan;
  final VoidCallback onSwap;
  final VoidCallback onP2P;
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
        _hero(context, totalValue, summary),
        const SizedBox(height: 12),
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
                _action('P2P', LucideIcons.briefcase, onP2P),
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
      return _status(LucideIcons.alertTriangle, 'Portfolio unavailable', state.error!, true);
    }
    if (state.isZeroBalance) {
      return _status(LucideIcons.wallet, 'Zero balance', 'Fund this wallet to start building a portfolio history.', false);
    }
    if (state.isEmpty) {
      return _status(LucideIcons.lineChart, 'No snapshots yet', 'The first snapshot appears after a wallet sync event.', false);
    }
    if (state.hasInsufficientData) {
      return _status(LucideIcons.activity, 'Insufficient data', 'We need at least two wallet snapshots to draw a chart.', false);
    }
    final positive = (summary?.absoluteChange ?? 0) >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Wallet history', 'Portfolio Chart', LucideIcons.lineChart),
        const SizedBox(height: 14),
        Text(
          currency.formatFiat(summary?.totalValue ?? liveTotalFiat),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _rangeText(state.selectedRange),
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 220,
          child: ChartArea(
            series: series,
            positive: positive,
            onHoverIndex: (_) {},
            accentColor: colors.primary,
            currentPrice: series.isNotEmpty ? series.last : null,
            timeLabels: labels,
            formatPrice: currency.formatFiat,
          ),
        ),
      ],
    );
  }

  Widget _activity(List<PortfolioActivityItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Wallet timeline', 'Recent Activity', LucideIcons.activity),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _status(LucideIcons.clock3, 'No recent activity', 'Send, receive, swap, and claim events will appear here.', false)
        else
          ...items.take(6).map((item) {
            final color = _activityColor(item.trigger);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border.withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(_activityIcon(item.trigger), color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_activityLabel(item.trigger), style: TextStyle(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(DateFormat('MMM d, HH:mm').format(item.timestamp), style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text(currency.formatFiat(item.totalValue), style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _sectionHeader(String eyebrow, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withValues(alpha: 0.16),
                colors.accent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: colors.primary, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.surface.withValues(alpha: 0.98),
            colors.surfaceRaised.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _status(IconData icon, String title, String subtitle, bool canRetry) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        const SizedBox(height: 14),
        Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        if (canRetry) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ],
    );
  }

  static String _shortAddress(String? value) {
    final address = (value ?? '').trim();
    if (address.isEmpty) return 'Wallet address unavailable';
    if (address.length <= 14) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  static String _labelFor(DateTime timestamp, PortfolioRange range) {
    switch (range) {
      case PortfolioRange.h24:
        return DateFormat('MMM d, HH:mm').format(timestamp);
      case PortfolioRange.d7:
      case PortfolioRange.d30:
        return DateFormat('MMM d').format(timestamp);
      case PortfolioRange.all:
        return DateFormat('MMM yyyy').format(timestamp);
    }
  }

  static String _rangeText(PortfolioRange range) {
    switch (range) {
      case PortfolioRange.h24:
        return 'Last 24 hours';
      case PortfolioRange.d7:
        return 'Last 7 days';
      case PortfolioRange.d30:
        return 'Last 30 days';
      case PortfolioRange.all:
        return 'All time';
    }
  }

  static String _activityLabel(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send:
        return 'Send';
      case WalletSnapshotTrigger.swap:
        return 'Swap';
      case WalletSnapshotTrigger.claim:
        return 'Claim';
      case WalletSnapshotTrigger.receiveDetected:
        return 'Receive';
      case WalletSnapshotTrigger.walletSwitch:
        return 'Wallet switch';
      case WalletSnapshotTrigger.manualRefresh:
        return 'Manual refresh';
      case WalletSnapshotTrigger.appOpen:
        return 'App open';
    }
  }

  Color _activityColor(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send:
        return colors.error;
      case WalletSnapshotTrigger.swap:
        return colors.primary;
      case WalletSnapshotTrigger.claim:
        return colors.success;
      case WalletSnapshotTrigger.receiveDetected:
        return colors.chartGreen;
      case WalletSnapshotTrigger.walletSwitch:
      case WalletSnapshotTrigger.manualRefresh:
      case WalletSnapshotTrigger.appOpen:
        return colors.textSecondary;
    }
  }

  static IconData _activityIcon(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send:
        return LucideIcons.arrowUpRight;
      case WalletSnapshotTrigger.swap:
        return LucideIcons.repeat2;
      case WalletSnapshotTrigger.claim:
        return LucideIcons.badgeCheck;
      case WalletSnapshotTrigger.receiveDetected:
        return LucideIcons.arrowDownLeft;
      case WalletSnapshotTrigger.walletSwitch:
      case WalletSnapshotTrigger.manualRefresh:
        return LucideIcons.refreshCw;
      case WalletSnapshotTrigger.appOpen:
        return LucideIcons.sparkles;
    }
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
