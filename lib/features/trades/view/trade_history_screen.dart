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
// TRADE HISTORY SCREEN  —  buyer perspective
// Design: Stripe-grade fintech — tight typography, grouped dates, clean density
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
    if (showLoader) setState(() { _loading = true; _error = null; });
    try {
      final result = await _tradesService.list(
        const TradesListQuery(page: 1, limit: 50),
      );
      if (!mounted) return;
      setState(() { _tradesList = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Group trades by date ──────────────────────────────────────────────────
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
      MaterialPageRoute(builder: (_) => TradeOrderScreen(trade: trade, offer: offer)),
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
            // ── Header ───────────────────────────────────────────────────────
            _Header(c: c, onRefresh: () => _loadTrades(showLoader: true)),

            // ── Summary Strip ─────────────────────────────────────────────────
            if (!_loading && _error == null && _tradesList.isNotEmpty)
              _SummaryStrip(c: c, trades: _tradesList),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const PageLoader(label: 'Loading trades…')
                  : _error != null
                  ? _ErrorState(c: c, error: _error!, onRetry: () => _loadTrades())
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.c, required this.onRefresh});
  final AppColor c;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(
        children: [
          if (canPop) ...[
            _IconBtn(
              c: c,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your trade history',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(
            c: c,
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
          ),
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
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Icon(icon, size: 17, color: c.textSecondary),
    ),
  );
}

// ─── Summary Strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.c, required this.trades});
  final AppColor c;
  final List<TradeModel> trades;

  @override
  Widget build(BuildContext context) {
    final buys = trades.where((t) => t.offerType == TradeOfferType.sell).length;
    final sells = trades.where((t) => t.offerType == TradeOfferType.buy).length;
    final completed = trades.where((t) => t.status == TradeStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            _StatCell(c: c, label: 'Buys', value: '$buys', accent: c.success),
            _VSep(c: c),
            _StatCell(c: c, label: 'Sells', value: '$sells', accent: c.error),
            _VSep(c: c),
            _StatCell(c: c, label: 'Done', value: '$completed', accent: c.primary),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.c, required this.label, required this.value, required this.accent});
  final AppColor c;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
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
      Container(width: 1, height: 28, color: c.border.withOpacity(0.2));
}

// ─── Trade List (grouped by date) ─────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: dates.length,
      itemBuilder: (_, i) {
        final date = dates[i];
        final trades = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 20),

            // Date header
            Row(
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.border.withOpacity(0.18),
                          c.border.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Trade cards for this date
            ...trades.map((trade) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TradeCard(c: c, trade: trade, onTap: () => onTap(trade)),
            )),
          ],
        );
      },
    );
  }
}

// ─── Trade Card ───────────────────────────────────────────────────────────────

class _TradeCard extends StatelessWidget {
  const _TradeCard({required this.c, required this.trade, required this.onTap});
  final AppColor c;
  final TradeModel trade;
  final VoidCallback onTap;

  bool get _isBuy => trade.offerType == TradeOfferType.sell;

  Color _statusColor(TradeStatus s) => switch (s) {
    TradeStatus.completed     => c.success,
    TradeStatus.cancelled     => c.error,
    TradeStatus.expired       => c.error,
    TradeStatus.disputed      => c.warning,
    TradeStatus.cryptoLocked  => c.primary,
    TradeStatus.fiatSent      => c.warning,
    TradeStatus.fiatConfirmed => c.primary,
    TradeStatus.created       => c.textSecondary,
    TradeStatus.unknown       => c.textSecondary,
  };

  String _statusLabel(TradeStatus s) => switch (s) {
    TradeStatus.completed     => 'Completed',
    TradeStatus.cancelled     => 'Cancelled',
    TradeStatus.expired       => 'Expired',
    TradeStatus.disputed      => 'Disputed',
    TradeStatus.cryptoLocked  => 'Locked',
    TradeStatus.fiatSent      => 'Fiat Sent',
    TradeStatus.fiatConfirmed => 'Confirming',
    TradeStatus.created       => 'Pending',
    TradeStatus.unknown       => 'Unknown',
  };

  String _formatCrypto(double amount) => amount.toStringAsFixed(4);
  String _formatFiat(double amount) {
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = _isBuy;
    final typeColor = isBuy ? c.success : c.error;
    final statusColor = _statusColor(trade.status);
    final statusLabel = _statusLabel(trade.status);
    final isActive = trade.status.isActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? statusColor.withOpacity(0.3)
                : c.border.withOpacity(0.18),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Direction badge ──────────────────────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    typeColor.withOpacity(0.16),
                    typeColor.withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.15)),
              ),
              child: Icon(
                isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: typeColor,
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            // ── Trade info ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type + asset
                  Row(
                    children: [
                      Text(
                        isBuy ? 'Buy' : 'Sell',
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trade.asset,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Amounts row
                  Row(
                    children: [
                      Text(
                        '${_formatCrypto(trade.cryptoAmount)} ${trade.asset}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: c.textSecondary.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        '${trade.fiatCurrency} ${_formatFiat(trade.fiatAmount)}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── Status badge ─────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: c.textSecondary.withOpacity(0.3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.textSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              color: c.textSecondary.withOpacity(0.4),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No trades yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your buy and sell history will appear here once you make your first trade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.c, required this.error, required this.onRetry});
  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load history',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Try again',
                style: TextStyle(
                  color: Colors.white,
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