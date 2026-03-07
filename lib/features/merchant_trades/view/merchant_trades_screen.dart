import 'dart:async';

import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT TRADES SCREEN  —  seller/merchant perspective
// Redesigned: Stripe-grade fintech UI — precise typography, clean density
// ─────────────────────────────────────────────────────────────────────────────

class MerchantTradesScreen extends StatefulWidget {
  const MerchantTradesScreen({super.key});

  @override
  State<MerchantTradesScreen> createState() => _MerchantTradesScreenState();
}

class _MerchantTradesScreenState extends State<MerchantTradesScreen>
    with WidgetsBindingObserver {
  final _tradesCore = TradesCoreService.I;

  bool _loading = true;
  String? _error;
  List<TradeModel> _trades = const [];
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final trades = await _tradesCore.list();
      if (!mounted) return;
      setState(() { _trades = trades; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
      if (!silent) {
        showFloatingSnackBar(context,
            message: 'Failed to load trades.', type: SnackBarType.error);
      }
    }
  }

  List<TradeModel> get _filtered {
    if (_activeFilter == null) return _trades;
    if (_activeFilter == true) return _trades.where((t) => t.status.isActive).toList();
    return _trades.where((t) => t.status.isTerminal).toList();
  }

  void _openTrade(TradeModel trade) {
    final offerMap = trade.offer;
    final offer = offerMap != null
        ? OfferModel.fromJson(offerMap)
        : OfferModel(
      id: trade.offerId,
      asset: trade.asset,
      fiatCurrency: trade.fiatCurrency,
      type: OfferType.sell,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeOrderScreen(trade: trade, offer: offer),
      ),
    ).then((_) => _load(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final filteredTrades = _filtered;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _Header(c: c, onRefresh: _load),

            // ── Summary Strip (only when loaded with data) ──────────────────
            if (!_loading && _error == null && _trades.isNotEmpty)
              _SummaryStrip(c: c, trades: _trades),

            // ── Filter Tabs ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _FilterRow(
                c: c,
                selected: _activeFilter,
                counts: {
                  null: _trades.length,
                  true: _trades.where((t) => t.status.isActive).length,
                  false: _trades.where((t) => t.status.isTerminal).length,
                },
                onChanged: (v) => setState(() => _activeFilter = v),
              ),
            ),

            // ── Section Label ─────────────────────────────────────────────
            if (!_loading && _error == null && filteredTrades.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Text(
                      '${filteredTrades.length} trade${filteredTrades.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const PageLoader(label: 'Loading trades…')
                  : _error != null
                  ? _ErrorState(c: c, error: _error!, onRetry: _load)
                  : RefreshIndicator(
                color: c.primary,
                onRefresh: _load,
                child: filteredTrades.isEmpty
                    ? _EmptyState(c: c, filter: _activeFilter)
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: filteredTrades.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TradeTile(
                      c: c,
                      trade: filteredTrades[i],
                      onTap: () => _openTrade(filteredTrades[i]),
                    ),
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
          // Back button — only shown when there's a route to pop
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
                  'Trades',
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
                  'Your merchant activity',
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
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
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
    final active = trades.where((t) => t.status.isActive).length;
    final completed = trades.where((t) => t.status == TradeStatus.completed).length;
    final totalFiat = trades
        .where((t) => t.status == TradeStatus.completed)
        .fold(0.0, (sum, t) => sum + t.fiatAmount);

    final currency = trades.isNotEmpty ? trades.first.fiatCurrency : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            _StatCell(c: c, label: 'Active', value: '$active', accent: c.warning),
            _VSep(c: c),
            _StatCell(c: c, label: 'Done', value: '$completed', accent: c.success),
            _VSep(c: c),
            _StatCell(
              c: c,
              label: 'Volume',
              value: totalFiat >= 1000
                  ? '$currency ${(totalFiat / 1000).toStringAsFixed(1)}K'
                  : '$currency ${totalFiat.toStringAsFixed(0)}',
              accent: c.primary,
            ),
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
    child: Container(
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
  Widget build(BuildContext context) => Container(
    width: 1, height: 28, color: c.border.withValues(alpha: 0.2),
  );
}

// ─── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.c,
    required this.selected,
    required this.counts,
    required this.onChanged,
  });
  final AppColor c;
  final bool? selected;
  final Map<bool?, int> counts;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _FilterChip(c: c, label: 'All', count: counts[null] ?? 0,
              active: selected == null, onTap: () => onChanged(null)),
          const SizedBox(width: 3),
          _FilterChip(c: c, label: 'Active', count: counts[true] ?? 0,
              active: selected == true, onTap: () => onChanged(true)),
          const SizedBox(width: 3),
          _FilterChip(c: c, label: 'Completed', count: counts[false] ?? 0,
              active: selected == false, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.c,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final AppColor c;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [BoxShadow(color: c.primary.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? c.onPrimary : c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? c.onPrimary.withValues(alpha: 0.25)
                      : c.textSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? c.onPrimary : c.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ─── Trade Tile ───────────────────────────────────────────────────────────────

class _TradeTile extends StatelessWidget {
  const _TradeTile({required this.c, required this.trade, required this.onTap});
  final AppColor c;
  final TradeModel trade;
  final VoidCallback onTap;

  _StatusMeta _meta(TradeStatus s) => switch (s) {
    TradeStatus.starting       => _StatusMeta('Request', c.textSecondary),
    TradeStatus.created        => _StatusMeta('Pending', c.textSecondary),
    TradeStatus.cryptoLocked   => _StatusMeta('Locked', c.warning),
    TradeStatus.fiatSent       => _StatusMeta('Fiat Sent', c.warning),
    TradeStatus.fiatConfirmed  => _StatusMeta('Confirming', c.primary),
    TradeStatus.completed      => _StatusMeta('Completed', c.success),
    TradeStatus.cancelled      => _StatusMeta('Cancelled', c.error),
    TradeStatus.disputed       => _StatusMeta('Disputed', c.error),
    TradeStatus.expired        => _StatusMeta('Expired', c.textSecondary),
    TradeStatus.unknown        => _StatusMeta('Unknown', c.textSecondary),
  };

  String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta(trade.status);
    final isActive = trade.status.isActive;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? meta.color.withValues(alpha: 0.3)
                : c.border.withValues(alpha: 0.18),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row ─────────────────────────────────────────────────────
            Row(
              children: [
                // Asset pill
                _AssetBadge(c: c, asset: trade.asset),
                const SizedBox(width: 12),

                // Pair + time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trade.asset} / ${trade.fiatCurrency}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(trade.createdAt),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                _StatusBadge(c: c, meta: meta),
              ],
            ),

            const SizedBox(height: 14),

            // ── Amounts Row ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  // Crypto amount
                  Expanded(
                    child: _AmountBlock(
                      c: c,
                      label: 'You receive',
                      value: trade.cryptoAmount.toStringAsFixed(4),
                      unit: trade.asset,
                      valueColor: c.primary,
                    ),
                  ),

                  // Arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: c.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),

                  // Fiat amount
                  Expanded(
                    child: _AmountBlock(
                      c: c,
                      label: 'Buyer pays',
                      value: _formatFiat(trade.fiatAmount),
                      unit: trade.fiatCurrency,
                      valueColor: c.success,
                      alignRight: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Footer Row ──────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  _shortId(trade.id),
                  style: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  'View details',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 12, color: c.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return '#$id';
    return '#${id.substring(0, 8).toUpperCase()}';
  }

  String _formatFiat(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }
}

class _StatusMeta {
  const _StatusMeta(this.label, this.color);
  final String label;
  final Color color;
}

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.c, required this.asset});
  final AppColor c;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final label = asset.length > 4 ? asset.substring(0, 4) : asset;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primary.withValues(alpha: 0.15),
            c.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.15)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: c.primary,
            fontWeight: FontWeight.w800,
            fontSize: label.length > 3 ? 9.5 : 11,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.c, required this.meta});
  final AppColor c;
  final _StatusMeta meta;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: meta.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: meta.color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          meta.label,
          style: TextStyle(
            color: meta.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ],
    ),
  );
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.c,
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    this.alignRight = false,
  });
  final AppColor c;
  final String label;
  final String value;
  final String unit;
  final Color valueColor;
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(height: 3),
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            TextSpan(
              text: '  $unit',
              style: TextStyle(
                color: valueColor.withValues(alpha: 0.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.filter});
  final AppColor c;
  final bool? filter;

  @override
  Widget build(BuildContext context) {
    final headline = filter == true
        ? 'No active trades'
        : filter == false
        ? 'No completed trades'
        : 'No trades yet';
    final sub = filter == true
        ? 'Incoming buyer orders will appear here once they initiate a trade.'
        : filter == false
        ? 'Completed trades will be archived here.'
        : 'Once buyers place orders against your offers, trades will appear here.';

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.receipt_long_outlined,
                      color: c.textSecondary.withValues(alpha: 0.5), size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sub,
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
        ),
      ],
    );
  }
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
              color: c.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load trades',
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
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.5),
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
