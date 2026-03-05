import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TRADE HISTORY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

enum _FilterTab { all, buy, sell }

class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _tradesService = TradesCoreService.I;
  final _dateFormat = DateFormat('MMM d, yyyy');

  bool _loading = true;
  String? _error;
  List<TradeModel> _tradesList = [];
  _FilterTab _activeFilter = _FilterTab.all;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadTrades();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadTrades({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
      _fadeCtrl.reset();
    }
    try {
      final result = await _tradesService.list(
        const TradesListQuery(page: 1, limit: 50),
      );
      if (!mounted) return;
      setState(() {
        _tradesList = result;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  List<TradeModel> get _filtered {
    return switch (_activeFilter) {
      _FilterTab.all => _tradesList,
      _FilterTab.buy =>
          _tradesList.where((t) => t.offerType == TradeOfferType.sell).toList(),
      _FilterTab.sell =>
          _tradesList.where((t) => t.offerType == TradeOfferType.buy).toList(),
    };
  }

  Map<String, List<TradeModel>> get _grouped {
    final map = <String, List<TradeModel>>{};
    for (final t in _filtered) {
      final key = t.createdAt != null
          ? _dateFormat.format(t.createdAt!.toLocal())
          : 'Unknown Date';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  int get _buyCount =>
      _tradesList.where((t) => t.offerType == TradeOfferType.sell).length;
  int get _sellCount =>
      _tradesList.where((t) => t.offerType == TradeOfferType.buy).length;
  int get _completedCount =>
      _tradesList.where((t) => t.status == TradeStatus.completed).length;
  int get _activeCount =>
      _tradesList.where((t) => t.status.isActive).length;

  void _openDetail(TradeModel trade) {
    OfferModel? offer;
    if (trade.offer != null) offer = OfferModel.fromJson(trade.offer!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TradeOrderScreen(trade: trade, offer: offer),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sticky header ────────────────────────────────────────────────
            _StickyHeader(
              c: c,
              buyCount: _buyCount,
              sellCount: _sellCount,
              completedCount: _completedCount,
              activeCount: _activeCount,
              showStats: !_loading && _error == null && _tradesList.isNotEmpty,
              activeFilter: _activeFilter,
              onFilterChanged: (f) => setState(() => _activeFilter = f),
              onRefresh: () => _loadTrades(showLoader: true),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const PageLoader(label: 'Loading trades…')
                  : _error != null
                  ? _ErrorState(
                c: c,
                error: _error!,
                onRetry: _loadTrades,
              )
                  : _filtered.isEmpty
                  ? _EmptyState(
                c: c,
                isFiltered: _activeFilter != _FilterTab.all,
              )
                  : FadeTransition(
                opacity: _fadeAnim,
                child: RefreshIndicator(
                  color: c.primary,
                  onRefresh: () =>
                      _loadTrades(showLoader: false),
                  child: _TradeList(
                    c: c,
                    grouped: _grouped,
                    onTap: _openDetail,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY HEADER  (title + stats + filter tabs — all in one widget)
// ─────────────────────────────────────────────────────────────────────────────

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.c,
    required this.buyCount,
    required this.sellCount,
    required this.completedCount,
    required this.activeCount,
    required this.showStats,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final AppColor c;
  final int buyCount;
  final int sellCount;
  final int completedCount;
  final int activeCount;
  final bool showStats;
  final _FilterTab activeFilter;
  final ValueChanged<_FilterTab> onFilterChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: c.background,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: back + title + refresh ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (canPop) ...[
                _NavBtn(
                  c: c,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trade History',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.7,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your buy & sell activity',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (activeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ActiveBadge(c: c, count: activeCount),
                ),
              _NavBtn(
                c: c,
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
          ),

          // ── Stats strip ─────────────────────────────────────────────────────
          if (showStats) ...[
            const SizedBox(height: 16),
            _StatsStrip(
              c: c,
              buyCount: buyCount,
              sellCount: sellCount,
              completedCount: completedCount,
            ),
          ],

          // ── Filter tabs ─────────────────────────────────────────────────────
          if (showStats) ...[
            const SizedBox(height: 14),
            _FilterTabs(
              c: c,
              active: activeFilter,
              onChanged: onFilterChanged,
              buyCount: buyCount,
              sellCount: sellCount,
              totalCount: buyCount + sellCount,
            ),
          ],

          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.c, required this.icon, required this.onTap});
  final AppColor c;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, size: 16, color: c.textSecondary),
    ),
  );
}

class _ActiveBadge extends StatefulWidget {
  const _ActiveBadge({required this.c, required this.count});
  final AppColor c;
  final int count;

  @override
  State<_ActiveBadge> createState() => _ActiveBadgeState();
}

class _ActiveBadgeState extends State<_ActiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.1 + _pulseAnim.value * 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: c.primary.withOpacity(0.3 + _pulseAnim.value * 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(_pulseAnim.value),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${widget.count} live',
              style: TextStyle(
                color: c.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.c,
    required this.buyCount,
    required this.sellCount,
    required this.completedCount,
  });
  final AppColor c;
  final int buyCount;
  final int sellCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _StatCell(c: c, label: 'Buys', value: '$buyCount', accent: c.success),
          _VDivider(c: c),
          _StatCell(c: c, label: 'Sells', value: '$sellCount', accent: c.error),
          _VDivider(c: c),
          _StatCell(
            c: c,
            label: 'Completed',
            value: '$completedCount',
            accent: c.primary,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.c,
    required this.label,
    required this.value,
    required this.accent,
  });
  final AppColor c;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: c.border);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER TABS
// ─────────────────────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.c,
    required this.active,
    required this.onChanged,
    required this.totalCount,
    required this.buyCount,
    required this.sellCount,
  });
  final AppColor c;
  final _FilterTab active;
  final ValueChanged<_FilterTab> onChanged;
  final int totalCount;
  final int buyCount;
  final int sellCount;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_FilterTab.all, 'All', totalCount),
      (_FilterTab.buy, 'Buys', buyCount),
      (_FilterTab.sell, 'Sells', sellCount),
    ];

    return Row(
      children: tabs.map((tab) {
        final (filter, label, count) = tab;
        final isActive = active == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? c.primary : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? c.primary : c.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? c.onPrimary : c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? c.onPrimary.withOpacity(0.2)
                          : c.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isActive ? c.onPrimary : c.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADE LIST
// ─────────────────────────────────────────────────────────────────────────────

class _TradeList extends StatelessWidget {
  const _TradeList({
    required this.c,
    required this.grouped,
    required this.onTap,
  });
  final AppColor c;
  final Map<String, List<TradeModel>> grouped;
  final ValueChanged<TradeModel> onTap;

  @override
  Widget build(BuildContext context) {
    final dates = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final trades = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 20),

            // ── Date header ────────────────────────────────────────────────
            _DateHeader(c: c, date: date, count: trades.length),
            const SizedBox(height: 10),

            // ── Trade cards ────────────────────────────────────────────────
            ...trades.map(
                  (trade) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TradeCard(
                  c: c,
                  trade: trade,
                  onTap: () => onTap(trade),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.c,
    required this.date,
    required this.count,
  });
  final AppColor c;
  final String date;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        date.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: c.border),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: c.border)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TradeCard extends StatefulWidget {
  const _TradeCard({
    required this.c,
    required this.trade,
    required this.onTap,
  });
  final AppColor c;
  final TradeModel trade;
  final VoidCallback onTap;

  @override
  State<_TradeCard> createState() => _TradeCardState();
}

class _TradeCardState extends State<_TradeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.974).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _isBuy => widget.trade.offerType == TradeOfferType.sell;

  Color _statusColor(TradeStatus s) {
    final c = widget.c;
    return switch (s) {
      TradeStatus.completed => c.success,
      TradeStatus.cancelled => c.error,
      TradeStatus.expired => c.error,
      TradeStatus.disputed => c.warning,
      TradeStatus.cryptoLocked => c.primary,
      TradeStatus.fiatSent => c.warning,
      TradeStatus.fiatConfirmed => c.primary,
      TradeStatus.created => c.textSecondary,
      TradeStatus.unknown => c.textSecondary,
    };
  }

  String _statusLabel(TradeStatus s) => switch (s) {
    TradeStatus.completed => 'Completed',
    TradeStatus.cancelled => 'Cancelled',
    TradeStatus.expired => 'Expired',
    TradeStatus.disputed => 'Disputed',
    TradeStatus.cryptoLocked => 'Escrowed',
    TradeStatus.fiatSent => 'Fiat Sent',
    TradeStatus.fiatConfirmed => 'Confirming',
    TradeStatus.created => 'Pending',
    TradeStatus.unknown => 'Unknown',
  };

  String _fmtCrypto(double v) => v < 0.001
      ? v.toStringAsFixed(7)
      : v < 1
      ? v.toStringAsFixed(5)
      : v.toStringAsFixed(4);

  String _fmtFiat(double v) =>
      v >= 1000000
          ? '${(v / 1000000).toStringAsFixed(2)}M'
          : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final trade = widget.trade;
    final isBuy = _isBuy;
    final typeColor = isBuy ? c.success : c.error;
    final statusColor = _statusColor(trade.status);
    final statusLabel = _statusLabel(trade.status);
    final isActive = trade.status.isActive;

    // Time label
    final timeLabel = trade.createdAt != null
        ? DateFormat('h:mm a').format(trade.createdAt!.toLocal())
        : '';

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              // ── Direction icon ─────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBuy
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: typeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 13),

              // ── Center: type + amounts ─────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: type label + time
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                isBuy ? 'Buy' : 'Sell',
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  trade.asset,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row 2: amounts + status pill
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${_fmtCrypto(trade.cryptoAmount)} ${trade.asset}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '·',
                                  style: TextStyle(color: c.border, fontSize: 14),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${trade.fiatCurrency} ${_fmtFiat(trade.fiatAmount)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status pill
                        _StatusPill(
                          label: statusLabel,
                          color: statusColor,
                          isActive: isActive,
                          c: c,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS PILL
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.isActive,
    required this.c,
  });
  final String label;
  final Color color;
  final bool isActive;
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 100),
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.isFiltered});
  final AppColor c;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
            ),
            child: Icon(
              isFiltered
                  ? Icons.filter_list_off_rounded
                  : Icons.swap_horiz_rounded,
              color: c.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'No results' : 'No trades yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'No trades match this filter. Try switching to All.'
                : 'Your buy and sell history will\nappear here after your first trade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.c,
    required this.error,
    required this.onRetry,
  });
  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.error.withOpacity(0.2)),
            ),
            child: Icon(Icons.cloud_off_rounded,
                color: c.error, size: 26),
          ),
          const SizedBox(height: 20),
          Text(
            'Couldn\'t load history',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.6,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: c.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                'Try again',
                style: TextStyle(
                  color: c.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
