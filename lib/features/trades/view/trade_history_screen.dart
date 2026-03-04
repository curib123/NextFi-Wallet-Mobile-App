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

class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  final _tradesService = TradesCoreService.I;
  final _dateFormat = DateFormat('MMM d, yyyy');

  bool _loading = true;
  String? _error;
  List<TradeModel> _tradesList = [];

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  Future<void> _loadTrades({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, List<TradeModel>> get _grouped {
    final map = <String, List<TradeModel>>{};
    for (final t in _tradesList) {
      final key = t.createdAt != null
          ? _dateFormat.format(t.createdAt!.toLocal())
          : 'Unknown Date';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  void _openDetail(TradeModel trade) {
    OfferModel? offer;
    if (trade.offer != null) offer = OfferModel.fromJson(trade.offer!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TradeOrderScreen(trade: trade, offer: offer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(c: c, onRefresh: () => _loadTrades(showLoader: true)),

            if (!_loading && _error == null && _tradesList.isNotEmpty)
              _SummaryStrip(c: c, trades: _tradesList),

            Expanded(
              child: _loading
                  ? const PageLoader(label: 'Loading trades…')
                  : _error != null
                  ? _ErrorState(
                      c: c,
                      error: _error!,
                      onRetry: () => _loadTrades(),
                    )
                  : _tradesList.isEmpty
                  ? _EmptyState(c: c)
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: () => _loadTrades(showLoader: false),
                      child: _TradeList(
                        c: c,
                        grouped: _grouped,
                        onTap: _openDetail,
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
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.c, required this.onRefresh});
  final AppColor c;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop) ...[
            _IconBtn(
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
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your buy & sell activity',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(c: c, icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.c, required this.icon, required this.onTap});
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
        boxShadow: [
          BoxShadow(
            color: c.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 17, color: c.textSecondary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.c, required this.trades});
  final AppColor c;
  final List<TradeModel> trades;

  @override
  Widget build(BuildContext context) {
    final buys = trades.where((t) => t.offerType == TradeOfferType.sell).length;
    final sells = trades.where((t) => t.offerType == TradeOfferType.buy).length;
    final completed = trades
        .where((t) => t.status == TradeStatus.completed)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _StatCell(c: c, label: 'Buys', value: '$buys', accent: c.success),
            _VSep(c: c),
            _StatCell(c: c, label: 'Sells', value: '$sells', accent: c.error),
            _VSep(c: c),
            _StatCell(
              c: c,
              label: 'Done',
              value: '$completed',
              accent: c.primary,
            ),
          ],
        ),
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VSep extends StatelessWidget {
  const _VSep({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: c.border);
}

// ─────────────────────────────────────────────────────────────────────────────
// TRADE LIST  (grouped by date)
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
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final trades = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 22),

            // ── Date header ──────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  date.toUpperCase(),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1, color: c.border)),
              ],
            ),

            const SizedBox(height: 10),

            // ── Cards ────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// TRADE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TradeCard extends StatefulWidget {
  const _TradeCard({required this.c, required this.trade, required this.onTap});
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
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
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
    TradeStatus.cryptoLocked => 'Locked',
    TradeStatus.fiatSent => 'Fiat Sent',
    TradeStatus.fiatConfirmed => 'Confirming',
    TradeStatus.created => 'Pending',
    TradeStatus.unknown => 'Unknown',
  };

  String _formatCrypto(double v) => v.toStringAsFixed(4);
  String _formatFiat(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final trade = widget.trade;
    final isBuy = _isBuy;
    final typeColor = isBuy ? c.success : c.error;
    final statusColor = _statusColor(trade.status);
    final statusLabel = _statusLabel(trade.status);
    final isActive = trade.status.isActive;

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.textPrimary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Direction badge ────────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.background,
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

              // ── Trade info ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type + asset
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isBuy ? 'Buy' : 'Sell',
                          style: TextStyle(
                            color: typeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
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
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Amounts
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatCrypto(trade.cryptoAmount)} ${trade.asset}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: c.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${trade.fiatCurrency} ${_formatFiat(trade.fiatAmount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Status + chevron ───────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status pill — solid color, no opacity
                  _StatusPill(
                    label: statusLabel,
                    color: statusColor,
                    isActive: isActive,
                    c: c,
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS PILL  — solid, no alpha
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
    constraints: const BoxConstraints(maxWidth: 110),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: c.onPrimary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.onPrimary,
              fontSize: 10.8,
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
  const _EmptyState({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              color: c.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No trades yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your buy and sell history will appear here once you make your first trade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w400,
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            'Couldn\'t load history',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
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
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                'Try again',
                style: TextStyle(
                  color: c.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
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
