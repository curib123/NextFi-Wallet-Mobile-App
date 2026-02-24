import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

class TradeHistoryScreen extends StatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  State<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

class _TradeHistoryScreenState extends State<TradeHistoryScreen> {
  final _trades = TradesCoreService.I;
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
      final result = await _trades.list(
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

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Text(
          'My Trades',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadTrades(showLoader: true),
            icon: Icon(Icons.refresh_rounded, color: c.textSecondary, size: 20),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const PageLoader(label: 'Loading trades...')
          : _error != null
              ? _buildError(c)
              : _tradesList.isEmpty
                  ? _buildEmpty(c)
                  : _buildTradeList(c),
    );
  }

  Widget _buildError(AppColor c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, color: c.error, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load trades',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _loadTrades(showLoader: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColor c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 48,
            color: c.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No trades yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your trade history will appear here',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeList(AppColor c) {
    // Group trades by date
    final groupedTrades = <String, List<TradeModel>>{};
    for (final trade in _tradesList) {
      final date = trade.createdAt != null
          ? _dateFormat.format(trade.createdAt!.toLocal())
          : 'Unknown Date';
      groupedTrades.putIfAbsent(date, () => []).add(trade);
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrades(showLoader: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedTrades.length,
        itemBuilder: (_, index) {
          final date = groupedTrades.keys.elementAt(index);
          final trades = groupedTrades[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 16),
              Text(
                date,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...trades.map((trade) => _TradeCard(
                c: c,
                trade: trade,
                onTap: () => _openTradeDetail(trade),
              )),
            ],
          );
        },
      ),
    );
  }

  void _openTradeDetail(TradeModel trade) {
    // Try to get the offer from trade data, or create a minimal offer model
    OfferModel? offer;
    if (trade.offer != null) {
      offer = OfferModel.fromJson(trade.offer!);
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TradeOrderScreen(
          trade: trade,
          offer: offer,
        ),
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    required this.c,
    required this.trade,
    required this.onTap,
  });

  final AppColor c;
  final TradeModel trade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = trade.status;
    final isBuy = trade.offerType == TradeOfferType.sell; // User buying = SELL offer
    final typeColor = isBuy ? c.success : c.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withOpacity(0.24)),
        ),
        child: Row(
          children: [
            // Type indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: typeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Trade info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isBuy ? 'Buy' : 'Sell',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trade.asset,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trade.cryptoAmount.toStringAsFixed(7)} ${trade.asset} · ${trade.fiatCurrency} ${trade.fiatAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TradeStatus status) {
    switch (status) {
      case TradeStatus.completed:
        return c.success;
      case TradeStatus.cancelled:
      case TradeStatus.expired:
        return c.error;
      case TradeStatus.disputed:
        return c.warning;
      case TradeStatus.cryptoLocked:
      case TradeStatus.fiatSent:
      case TradeStatus.fiatConfirmed:
        return c.primary;
      case TradeStatus.created:
        return c.textSecondary;
      default:
        return c.textSecondary;
    }
  }
}
