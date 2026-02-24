import 'dart:async';

import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MERCHANT TRADES SCREEN  —  seller/merchant perspective
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

  // Filter: null = all, isActive = true/false
  bool? _activeFilter; // null = all, true = active, false = completed

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
      final trades = await _tradesCore.list(
        query: const TradesListQuery(role: 'seller', limit: 100),
      );
      if (!mounted) return;
      setState(() {
        _trades = trades;
        _loading = false;
      });
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
            type: OfferType.sell, // merchant created a SELL offer
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
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'My Trades',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 20),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _FilterTabs(
              c: c,
              selected: _activeFilter,
              onChanged: (v) => setState(() => _activeFilter = v),
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const PageLoader(label: 'Loading trades…')
                : _error != null
                    ? _ErrorState(c: c, error: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? _EmptyState(c: c, filter: _activeFilter)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _TradeTile(
                                    c: c,
                                    trade: _filtered[i],
                                    onTap: () => _openTrade(_filtered[i]),
                                  ),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Tabs ─────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.c,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final bool? selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _Tab(c: c, label: 'All', active: selected == null,
              onTap: () => onChanged(null)),
          const SizedBox(width: 3),
          _Tab(c: c, label: 'Active', active: selected == true,
              onTap: () => onChanged(true)),
          const SizedBox(width: 3),
          _Tab(c: c, label: 'Completed', active: selected == false,
              onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.c, required this.label, required this.active, required this.onTap});
  final AppColor c;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
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

  Color _statusColor(TradeStatus s) => switch (s) {
    TradeStatus.fiatSent   => c.warning,
    TradeStatus.completed  => c.success,
    TradeStatus.cancelled  => c.error,
    TradeStatus.disputed   => c.error,
    TradeStatus.unknown    => c.textSecondary,
    // TODO: Handle this case.
    TradeStatus.created => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.cryptoLocked => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.fiatConfirmed => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.expired => throw UnimplementedError(),
  };

  String _statusLabel(TradeStatus s) => switch (s) {
    TradeStatus.fiatSent     => 'Fiat Sent',
    TradeStatus.completed    => 'Completed',
    TradeStatus.cancelled    => 'Cancelled',
    TradeStatus.disputed     => 'Disputed',
    TradeStatus.unknown      => 'Unknown',
    // TODO: Handle this case.
    TradeStatus.created => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.cryptoLocked => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.fiatConfirmed => throw UnimplementedError(),
    // TODO: Handle this case.
    TradeStatus.expired => throw UnimplementedError(),
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
    final statusColor = _statusColor(trade.status);
    final statusLabel = _statusLabel(trade.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: asset pair + status chip
            Row(
              children: [
                // Asset icon placeholder
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      trade.asset.length > 3
                          ? trade.asset.substring(0, 3)
                          : trade.asset,
                      style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(trade.createdAt),
                        style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _Divider(c: c),
            const SizedBox(height: 10),

            // Amounts
            Row(
              children: [
                Expanded(
                  child: _AmountCell(
                    c: c,
                    label: 'Crypto',
                    value: '${trade.cryptoAmount.toStringAsFixed(4)} ${trade.asset}',
                    color: c.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: c.border.withOpacity(0.15),
                ),
                Expanded(
                  child: _AmountCell(
                    c: c,
                    label: 'Fiat',
                    value: '${trade.fiatCurrency} ${trade.fiatAmount.toStringAsFixed(2)}',
                    color: c.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Trade ID truncated
            Row(
              children: [
                Icon(Icons.tag_rounded, size: 12, color: c.textSecondary.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  trade.id.length > 20 ? '${trade.id.substring(0, 20)}…' : trade.id,
                  style: TextStyle(
                    color: c.textSecondary.withOpacity(0.5),
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16, color: c.textSecondary.withOpacity(0.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.c, required this.label, required this.value, required this.color});
  final AppColor c;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          c.border.withOpacity(0),
          c.border.withOpacity(0.18),
          c.border.withOpacity(0),
        ],
      ),
    ),
  );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.filter});
  final AppColor c;
  final bool? filter;

  String get _label {
    if (filter == true) return 'No active trades right now';
    if (filter == false) return 'No completed trades yet';
    return 'No trades yet';
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, color: c.textSecondary, size: 30),
              const SizedBox(height: 12),
              Text(
                _label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Incoming buyer trades will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.c, required this.error, required this.onRetry});
  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: c.error, size: 30),
          const SizedBox(height: 10),
          Text(error, textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.primary.withOpacity(0.2)),
              ),
              child: Text('Try again',
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}
