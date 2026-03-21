import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/widgets/asset/asset_remote_image.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_state.dart';
import 'package:next_fi/features/price_chart/presentation/widgets/chart_area.dart';

class PortfolioOverviewSection extends StatelessWidget {
  const PortfolioOverviewSection({
    super.key,
    required this.colors,
    required this.state,
    required this.currency,
    required this.liveTotalFiat,
    required this.liveAssets,
    required this.balancesByAssetId,
    required this.onSend,
    required this.onReceive,
    required this.onSwap,
    required this.onP2P,
    required this.onRetry,
    required this.onRangeChanged,
  });

  final AppColor colors;
  final PortfolioState state;
  final CurrencyVM currency;
  final double liveTotalFiat;
  final List<AssetModel> liveAssets;
  final Map<String, double> balancesByAssetId;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onSwap;
  final VoidCallback onP2P;
  final Future<void> Function() onRetry;
  final ValueChanged<PortfolioRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final summary = state.data?.summary;
    final totalValue = summary?.totalValue ?? liveTotalFiat;
    final allocation = state.data?.allocation.isNotEmpty == true
        ? state.data!.allocation
        : _liveAllocation();
    final chart = state.data?.chart ?? const <PortfolioChartPoint>[];
    final chartSeries = chart.map((point) => point.totalValue).toList(growable: false);
    final labels = chart
        .map((point) => _formatLabel(point.timestamp, state.selectedRange))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(
          totalValue: totalValue,
          absoluteChange: summary?.absoluteChange ?? 0,
          percentChange: summary?.percentChange ?? 0,
          lastUpdated: summary?.lastUpdated,
        ),
        const SizedBox(height: 16),
        _ranges(),
        const SizedBox(height: 14),
        _card(child: _chart(chartSeries, labels, totalValue, summary)),
        const SizedBox(height: 14),
        _card(child: _allocation(allocation)),
        const SizedBox(height: 14),
        _card(child: _activity(state.data?.activity ?? const [])),
      ],
    );
  }

  Widget _hero({
    required double totalValue,
    required double absoluteChange,
    required double percentChange,
    required DateTime? lastUpdated,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(colors.background);
    final isDark = brightness == Brightness.dark;
    final positive = absoluteChange >= 0;
    final accent = positive ? colors.chartGreen : colors.chartRed;
    final heroTextPrimary = isDark ? colors.textPrimary : const Color(0xFF0B172A);
    final heroTextSecondary = isDark
        ? colors.textSecondary.withValues(alpha: 0.92)
        : const Color(0xFF52627C);
    final heroSurface = isDark
        ? colors.surfaceRaised.withValues(alpha: 0.92)
        : colors.surface;
    final heroTop = isDark
        ? colors.primaryDark.withValues(alpha: 0.96)
        : const Color(0xFFF8FBFF);
    final heroBottom = isDark
        ? colors.surface.withValues(alpha: 0.98)
        : colors.surfaceRaised.withValues(alpha: 0.98);
    final heroGlow = isDark
        ? colors.primary.withValues(alpha: 0.18)
        : colors.primary.withValues(alpha: 0.08);
    final valuePanel = isDark
        ? colors.surfaceOverlay.withValues(alpha: 0.68)
        : colors.primary.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            heroTop,
            heroBottom,
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
        border: Border.all(
          color: isDark
              ? colors.border.withValues(alpha: 0.55)
              : colors.primary.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: heroGlow,
            blurRadius: isDark ? 26 : 18,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Portfolio balance',
                        style: AppFonts.label(
                          color: colors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.walletLabel?.trim().isNotEmpty == true
                          ? state.walletLabel!.trim()
                          : 'Active wallet',
                      style: AppFonts.title(
                        color: heroTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shortAddress(state.activeWalletAddress),
                      style: AppFonts.body(
                        color: heroTextSecondary,
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
                  color: heroSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.border.withValues(alpha: isDark ? 0.45 : 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Updated',
                      style: AppFonts.label(
                        color: heroTextSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastUpdated == null
                          ? 'Waiting'
                          : DateFormat('MMM d, HH:mm').format(lastUpdated),
                      style: AppFonts.body(
                        color: heroTextPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: valuePanel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.border.withValues(alpha: isDark ? 0.35 : 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.formatFiat(totalValue),
                  style: AppFonts.display(
                    color: heroTextPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            positive
                                ? LucideIcons.trendingUp
                                : LucideIcons.trendingDown,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${positive ? '+' : ''}${percentChange.toStringAsFixed(2)}%',
                            style: AppFonts.label(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currency.formatSignedFiat(absoluteChange),
                      style: AppFonts.body(
                        color: heroTextPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _action(
                'Send',
                LucideIcons.arrowUpRight,
                onSend,
                textColor: heroTextPrimary,
                iconColor: colors.primary,
                backgroundColor: heroSurface,
                borderColor: colors.border.withValues(alpha: isDark ? 0.40 : 0.16),
              ),
              _action(
                'Receive',
                LucideIcons.arrowDownLeft,
                onReceive,
                textColor: heroTextPrimary,
                iconColor: colors.success,
                backgroundColor: heroSurface,
                borderColor: colors.border.withValues(alpha: isDark ? 0.40 : 0.16),
              ),
              _action(
                'Swap',
                LucideIcons.repeat2,
                onSwap,
                textColor: heroTextPrimary,
                iconColor: colors.primary,
                backgroundColor: heroSurface,
                borderColor: colors.border.withValues(alpha: isDark ? 0.40 : 0.16),
              ),
              _action(
                'P2P',
                LucideIcons.briefcase,
                onP2P,
                textColor: heroTextPrimary,
                iconColor: colors.warning,
                backgroundColor: heroSurface,
                borderColor: colors.border.withValues(alpha: isDark ? 0.40 : 0.16),
              ),
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
      children: options.map((option) {
        final selected = option.$1 == state.selectedRange;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onRangeChanged(option.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected
                    ? colors.primary
                    : colors.surface.withValues(alpha: 0.82),
                border: Border.all(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.55)
                      : colors.border.withValues(alpha: 0.22),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                option.$2,
                style: AppFonts.label(
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

  Widget _chart(List<double> chartSeries, List<String> labels, double totalValue, PortfolioSummary? summary) {
    if (state.loading) return const _Skeleton(height: 220);
    if (state.isOffline && !state.hasData) return _status(LucideIcons.wifiOff, 'Offline portfolio', 'Reconnect to load wallet-scoped history.');
    if (state.error != null) return _status(LucideIcons.alertTriangle, 'Portfolio unavailable', state.error!, retry: onRetry);
    if (state.isZeroBalance) return _status(LucideIcons.wallet, 'Zero balance', 'Fund this wallet to start building a portfolio history.');
    if (state.isEmpty) return _status(LucideIcons.lineChart, 'No snapshots yet', 'The first snapshot appears after a fresh wallet event.');
    if (state.hasInsufficientData) return _status(LucideIcons.activity, 'Insufficient data', 'We need at least two wallet snapshots to draw a chart.');
    final positive = (summary?.absoluteChange ?? 0) >= 0;
    final accent = positive ? colors.chartGreen : colors.chartRed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(
        icon: LucideIcons.lineChart,
        eyebrow: 'Wallet history',
        title: 'Portfolio Chart',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${positive ? '+' : ''}${(summary?.percentChange ?? 0).toStringAsFixed(2)}%',
            style: AppFonts.label(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.formatFiat(totalValue),
                    style: AppFonts.headline(
                      color: colors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _rangeLabel(state.selectedRange),
                    style: AppFonts.body(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                summary?.lastUpdated == null
                    ? 'Waiting'
                    : DateFormat('MMM d').format(summary!.lastUpdated),
                style: AppFonts.label(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 220,
        child: ChartArea(
          series: chartSeries,
          positive: positive,
          onHoverIndex: (_) {},
          accentColor: colors.primary,
          currentPrice: chartSeries.isNotEmpty ? chartSeries.last : null,
          timeLabels: labels,
          formatPrice: (value) => currency.formatFiat(value),
        ),
      ),
    ]);
  }

  Widget _allocation(List<dynamic> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(
        icon: LucideIcons.pieChart,
        eyebrow: 'Wallet composition',
        title: 'Asset Allocation',
        trailing: Text(
          '${items.length} assets',
          style: AppFonts.label(
            color: colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty) _status(LucideIcons.pieChart, 'No allocation data', 'Allocation will appear after this wallet holds assets.')
      else ...items.map((item) {
        final code = item is PortfolioAllocationItem ? item.code : item['code'] as String;
        final balance = item is PortfolioAllocationItem ? item.balance : item['balance'] as double;
        final fiatValue = item is PortfolioAllocationItem ? item.fiatValue : item['fiatValue'] as double;
        final allocationPercent = item is PortfolioAllocationItem ? item.allocationPercent : item['allocationPercent'] as double;
        final logoUrl = _logoUrlForCode(code);
        final tileAccent = (code == 'XLM' ? colors.primary : colors.success);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.14),
              ),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tileAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AssetRemoteImage(
                    url: logoUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    placeholder: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            valueColor: AlwaysStoppedAnimation<Color>(tileAccent),
                          ),
                        ),
                      ),
                    ),
                    fallback: Text(
                      code,
                      style: AppFonts.label(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  code,
                  style: AppFonts.body(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${balance.toStringAsFixed(code == 'USDC' ? 2 : 4)} $code',
                  style: AppFonts.body(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  currency.formatFiat(fiatValue),
                  style: AppFonts.body(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tileAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${allocationPercent.toStringAsFixed(1)}%',
                    style: AppFonts.label(
                      color: tileAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _activity(List<PortfolioActivityItem> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader(
        icon: LucideIcons.activity,
        eyebrow: 'Wallet timeline',
        title: 'Recent Activity',
        trailing: Text(
          '${items.take(6).length} events',
          style: AppFonts.label(
            color: colors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty) _status(LucideIcons.clock3, 'No recent activity', 'Send, receive, swap, and claim events will appear here.')
      else ...items.take(6).map((item) {
        final eventColor = _activityColor(item.trigger);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.14),
              ),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(_activityIcon(item.trigger), color: eventColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activityLabel(item.trigger),
                      style: AppFonts.body(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activitySubtitle(item.trigger),
                      style: AppFonts.body(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM d, HH:mm').format(item.timestamp),
                style: AppFonts.label(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _sectionHeader({
    required IconData icon,
    required String eyebrow,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
              Text(
                eyebrow,
                style: AppFonts.label(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppFonts.title(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback onTap, {
    required Color textColor,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.label(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final brightness = ThemeData.estimateBrightnessForColor(colors.background);
    final isDark = brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: isDark ? 0.96 : 0.98),
            colors.surfaceRaised.withValues(alpha: isDark ? 0.92 : 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: isDark ? 0.22 : 0.16)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: isDark ? 18 : 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _status(IconData icon, String title, String subtitle, {Future<void> Function()? retry}) {
    return Column(children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.12),
              colors.surface.withValues(alpha: 0.72),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: colors.primary, size: 22),
      ),
      const SizedBox(height: 14),
      Text(
        title,
        style: AppFonts.title(
          color: colors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AppFonts.body(
          color: colors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (retry != null) ...[
        const SizedBox(height: 14),
        FilledButton(onPressed: () => retry(), child: const Text('Retry')),
      ],
    ]);
  }

  List<Map<String, dynamic>> _liveAllocation() {
    final items = <Map<String, dynamic>>[];
    var total = 0.0;
    for (final asset in liveAssets) {
      final code = asset.symbol.trim().toUpperCase();
      if (!(code == 'XLM' || code == 'USDC')) continue;
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      final fiatValue = currency.assetAmountToFiat(asset, balance);
      total += fiatValue;
      items.add({'code': code, 'balance': balance, 'fiatValue': fiatValue, 'allocationPercent': 0.0});
    }
    if (total <= 0) return items;
    return items
        .map(
          (item) => {
            ...item,
            'allocationPercent':
                (((item['fiatValue'] as double) / total) * 100),
          },
        )
        .toList(growable: false);
  }

  String? _logoUrlForCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;

    AssetModel? match;
    for (final asset in liveAssets) {
      final symbol = asset.symbol.trim().toUpperCase();
      final assetCode = (asset.assetCode ?? '').trim().toUpperCase();
      if (symbol == normalizedCode || assetCode == normalizedCode) {
        match = asset;
        break;
      }
    }

    final logo = match?.primaryLogo.trim() ?? '';
    return logo.isEmpty ? null : logo;
  }

  static String _shortAddress(String? address) {
    final value = (address ?? '').trim();
    if (value.isEmpty) return 'Wallet address unavailable';
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }

  static String _formatLabel(DateTime timestamp, PortfolioRange range) {
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

  static String _rangeLabel(PortfolioRange range) {
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
      case WalletSnapshotTrigger.send: return 'Send';
      case WalletSnapshotTrigger.swap: return 'Swap';
      case WalletSnapshotTrigger.claim: return 'Claim';
      case WalletSnapshotTrigger.receiveDetected: return 'Receive';
      case WalletSnapshotTrigger.walletSwitch: return 'Wallet switch';
      case WalletSnapshotTrigger.manualRefresh: return 'Manual refresh';
      case WalletSnapshotTrigger.appOpen: return 'App open';
    }
  }

  static String _activitySubtitle(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send:
        return 'Funds sent from this wallet';
      case WalletSnapshotTrigger.swap:
        return 'Assets exchanged successfully';
      case WalletSnapshotTrigger.claim:
        return 'Claim completed on-chain';
      case WalletSnapshotTrigger.receiveDetected:
        return 'Incoming funds detected';
      case WalletSnapshotTrigger.walletSwitch:
        return 'Wallet context refreshed';
      case WalletSnapshotTrigger.manualRefresh:
        return 'Balances refreshed manually';
      case WalletSnapshotTrigger.appOpen:
        return 'Fresh session snapshot recorded';
    }
  }

  Color _activityColor(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send: return colors.error;
      case WalletSnapshotTrigger.swap: return colors.primary;
      case WalletSnapshotTrigger.claim: return colors.success;
      case WalletSnapshotTrigger.receiveDetected: return colors.chartGreen;
      case WalletSnapshotTrigger.walletSwitch:
      case WalletSnapshotTrigger.manualRefresh:
      case WalletSnapshotTrigger.appOpen:
        return colors.textSecondary;
    }
  }

  static IconData _activityIcon(WalletSnapshotTrigger trigger) {
    switch (trigger) {
      case WalletSnapshotTrigger.send: return LucideIcons.arrowUpRight;
      case WalletSnapshotTrigger.swap: return LucideIcons.repeat2;
      case WalletSnapshotTrigger.claim: return LucideIcons.badgeCheck;
      case WalletSnapshotTrigger.receiveDetected: return LucideIcons.arrowDownLeft;
      case WalletSnapshotTrigger.walletSwitch:
      case WalletSnapshotTrigger.manualRefresh: return LucideIcons.refreshCw;
      case WalletSnapshotTrigger.appOpen: return LucideIcons.sparkles;
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
