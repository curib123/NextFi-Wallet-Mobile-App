import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/features/merchant_request/view/merchant_request_screen.dart';
import 'package:next_fi/features/trades/view/trade_order_screen.dart';
import 'package:next_fi/features/trades/view/trade_template_screen.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/models/trades_models.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

class MerchantTradesScreen extends StatefulWidget {
  const MerchantTradesScreen({super.key});

  @override
  State<MerchantTradesScreen> createState() => _MerchantTradesScreenState();
}

class _MerchantTradesScreenState extends State<MerchantTradesScreen> {
  final _auth = AuthService();
  final _profile = ProfileCoreService.I;
  final _trades = TradesCoreService.I;
  final _searchCtrl = TextEditingController();
  final _money = NumberFormat.currency(symbol: '', decimalDigits: 2);

  bool _loading = true;
  bool _isMerchant = false;
  String? _error;
  String? _currentUserId;
  String? _statusFilter;
  List<TradeModel> _items = const [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadTrades(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      try {
        _currentUserId = (await _auth.currentUser).id;
      } catch (_) {
        _currentUserId = null;
      }
      final me = await _profile.getMe();
      final isMerchant = me?.isMerchant == true;
      if (!mounted) return;
      if (!isMerchant) {
        setState(() {
          _isMerchant = false;
          _loading = false;
          _items = const [];
        });
        return;
      }

      setState(() => _isMerchant = true);
      await _loadTrades(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadTrades({required bool showLoader}) async {
    if (!_isMerchant && !showLoader) return;

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final query = TradesQuery(
        status: _statusFilter,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        page: 1,
        limit: 100,
      );
      final items = await _trades.listSellerTrades(query);
      if (!mounted) return;
      items.sort(
        (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
          a.updatedAt ?? a.createdAt ?? DateTime(1970),
        ),
      );
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openTrade(TradeModel trade) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TradeOrderScreen(
          tradeId: trade.id,
          asSeller: true,
          mode: TradeTemplateMode.sell,
        ),
      ),
    );
    if (mounted) {
      await _loadTrades(showLoader: false);
    }
  }

  String _statusLabel(TradeStatus status, String raw) {
    switch (status) {
      case TradeStatus.created:
        return 'Created';
      case TradeStatus.awaitingPayment:
        return 'Awaiting Payment';
      case TradeStatus.paid:
        return 'Paid';
      case TradeStatus.released:
        return 'Released';
      case TradeStatus.cancelled:
        return 'Cancelled';
      case TradeStatus.disputed:
        return 'Disputed';
      case TradeStatus.expired:
        return 'Expired';
      case TradeStatus.refunded:
        return 'Refunded';
      case TradeStatus.unknown:
        return raw;
    }
  }

  Color _statusColor(AppColor c, TradeStatus status) {
    switch (status) {
      case TradeStatus.created:
      case TradeStatus.awaitingPayment:
        return c.warning;
      case TradeStatus.paid:
      case TradeStatus.released:
        return c.success;
      case TradeStatus.disputed:
        return c.error;
      case TradeStatus.cancelled:
      case TradeStatus.expired:
      case TradeStatus.refunded:
      case TradeStatus.unknown:
        return c.textSecondary;
    }
  }

  int get _openCount => _items.where((e) => !e.isFinalStatus).length;
  int get _paidCount =>
      _items.where((e) => e.status == TradeStatus.paid).length;
  int get _disputedCount =>
      _items.where((e) => e.status == TradeStatus.disputed).length;
  int get _pendingChatCount {
    final me = _currentUserId?.trim() ?? '';
    if (me.isEmpty) return 0;
    var count = 0;
    for (final trade in _items) {
      if (trade.isFinalStatus || trade.messages.isEmpty) continue;
      final last = trade.messages.last;
      if (last.senderId.trim().isNotEmpty && last.senderId != me) {
        count++;
      }
    }
    return count;
  }

  String _counterpartyTitle(TradeModel trade) {
    final party = trade.counterpartyFor(_currentUserId);
    if (party != null) {
      final display = party.displayName?.trim() ?? '';
      if (display.isNotEmpty) return display;
      final name = party.name.trim();
      if (name.isNotEmpty) return name;
      final username = party.username?.trim() ?? '';
      if (username.isNotEmpty) return '@$username';
      final email = party.email.trim();
      if (email.isNotEmpty) return email;
    }

    final isSeller = trade.sellerId == (_currentUserId?.trim() ?? '');
    final fallbackId = isSeller ? trade.buyerId : trade.sellerId;
    if (fallbackId.isNotEmpty) return fallbackId;
    return 'Counterparty';
  }

  String _counterpartySubtitle(TradeModel trade) {
    final party = trade.counterpartyFor(_currentUserId);
    if (party == null) return '';
    final username = party.username?.trim() ?? '';
    final email = party.email.trim();
    if (username.isNotEmpty && email.isNotEmpty) return '@$username | $email';
    if (username.isNotEmpty) return '@$username';
    if (email.isNotEmpty) return email;
    return '';
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
          'Merchant Trades',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isMerchant
          ? _NotMerchantView(
              c: c,
              onOpenRequest: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantRequestScreen(),
                  ),
                );
              },
            )
          : RefreshIndicator(
              onRefresh: () => _loadTrades(showLoader: false),
              color: c.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  _HeroCard(
                    c: c,
                    openCount: _openCount,
                    paidCount: _paidCount,
                    disputedCount: _disputedCount,
                    pendingChatCount: _pendingChatCount,
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(c: c, label: 'FILTERS'),
                  const SizedBox(height: 8),
                  _FilterCard(
                    c: c,
                    searchCtrl: _searchCtrl,
                    statusFilter: _statusFilter,
                    onSearch: () => _loadTrades(showLoader: true),
                    onStatusChanged: (value) {
                      setState(() => _statusFilter = value);
                      _loadTrades(showLoader: true);
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(c: c, label: 'INCOMING TRADES'),
                  const SizedBox(height: 8),
                  if (_error != null)
                    _ErrorCard(c: c, message: _error!, onRetry: _bootstrap)
                  else if (_items.isEmpty)
                    _EmptyCard(c: c)
                  else
                    ..._items.map(
                      (trade) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TradeCard(
                          c: c,
                          trade: trade,
                          priceLabel: _money.format(trade.price ?? 0),
                          statusLabel: _statusLabel(
                            trade.status,
                            trade.statusRaw,
                          ),
                          statusColor: _statusColor(c, trade.status),
                          counterpartyTitle: _counterpartyTitle(trade),
                          counterpartySubtitle: _counterpartySubtitle(trade),
                          hasUnread:
                              !trade.isFinalStatus &&
                              trade.messages.isNotEmpty &&
                              trade.messages.last.senderId !=
                                  (_currentUserId ?? ''),
                          onOpen: () => _openTrade(trade),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NotMerchantView extends StatelessWidget {
  const _NotMerchantView({required this.c, required this.onOpenRequest});

  final AppColor c;
  final VoidCallback onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.warning.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.storefront_outlined, color: c.warning),
              ),
              const SizedBox(height: 12),
              Text(
                'Merchant access required',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Only merchant accounts can access seller trade routes.',
                style: TextStyle(color: c.textSecondary, fontSize: 12.8),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: AppElevatedButton.icon(
                  onPressed: onOpenRequest,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: const Text('Open Merchant Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.c,
    required this.openCount,
    required this.paidCount,
    required this.disputedCount,
    required this.pendingChatCount,
  });

  final AppColor c;
  final int openCount;
  final int paidCount;
  final int disputedCount;
  final int pendingChatCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TRADE INBOX',
              style: TextStyle(
                color: c.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Respond quickly to protect completion rate',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open a trade to chat in realtime, verify proof, and release escrow safely.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.7,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricPill(c: c, label: 'Open', value: '$openCount'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(c: c, label: 'Paid', value: '$paidCount'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  c: c,
                  label: 'Disputed',
                  value: '$disputedCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  c: c,
                  label: 'Chat',
                  value: '$pendingChatCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.c,
    required this.label,
    required this.value,
  });

  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.c, required this.label});

  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.c,
    required this.searchCtrl,
    required this.statusFilter,
    required this.onSearch,
    required this.onStatusChanged,
  });

  final AppColor c;
  final TextEditingController searchCtrl;
  final String? statusFilter;
  final VoidCallback onSearch;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder fieldBorder() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.border.withOpacity(0.24)),
    );
    OutlineInputBorder fieldFocused() => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.primary.withOpacity(0.42), width: 1.2),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Search by trade id, asset, reason',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: c.textSecondary.withOpacity(0.7),
              ),
              filled: true,
              fillColor: c.background,
              border: fieldBorder(),
              enabledBorder: fieldBorder(),
              focusedBorder: fieldFocused(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                c: c,
                selected: statusFilter == null,
                label: 'ALL',
                onTap: () => onStatusChanged(null),
              ),
              _StatusChip(
                c: c,
                selected: statusFilter == 'AWAITING_PAYMENT',
                label: 'Awaiting',
                onTap: () => onStatusChanged('AWAITING_PAYMENT'),
              ),
              _StatusChip(
                c: c,
                selected: statusFilter == 'PAID',
                label: 'Paid',
                onTap: () => onStatusChanged('PAID'),
              ),
              _StatusChip(
                c: c,
                selected: statusFilter == 'DISPUTED',
                label: 'Disputed',
                onTap: () => onStatusChanged('DISPUTED'),
              ),
              _StatusChip(
                c: c,
                selected: statusFilter == 'RELEASED',
                label: 'Released',
                onTap: () => onStatusChanged('RELEASED'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.c,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AppColor c;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary.withOpacity(0.1) : c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? c.primary.withOpacity(0.4)
                : c.border.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.primary : c.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    required this.c,
    required this.trade,
    required this.priceLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.counterpartyTitle,
    required this.counterpartySubtitle,
    required this.hasUnread,
    required this.onOpen,
  });

  final AppColor c;
  final TradeModel trade;
  final String priceLabel;
  final String statusLabel;
  final Color statusColor;
  final String counterpartyTitle;
  final String counterpartySubtitle;
  final bool hasUnread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final latestMessage = trade.messages.isNotEmpty
        ? trade.messages.last
        : null;
    final shortTrade = trade.id.length > 10
        ? trade.id.substring(0, 10)
        : trade.id;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.error.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.error.withOpacity(0.25)),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(
                      color: c.error,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                '#$shortTrade',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${offerAssetToApi(trade.asset)} / ${trade.fiatCurrency}',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            counterpartyTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (counterpartySubtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              counterpartySubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, fontSize: 11.7),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '${trade.amount.toStringAsFixed(2)} ${trade.fiatCurrency}',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Price: $priceLabel ${trade.fiatCurrency}',
            style: TextStyle(color: c.textSecondary, fontSize: 12.2),
          ),
          if (latestMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: c.border.withOpacity(0.22)),
              ),
              child: Text(
                '${hasUnread ? '$counterpartyTitle: ' : ''}${latestMessage.message}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.2,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: AppElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Open Trade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.c,
    required this.message,
    required this.onRetry,
  });

  final AppColor c;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load trades.',
            style: TextStyle(
              color: c.error,
              fontSize: 13.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: c.textPrimary, fontSize: 12.4)),
          const SizedBox(height: 10),
          AppOutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.textPrimary,
              side: BorderSide(color: c.border.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.inbox, size: 18, color: c.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No trades yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Trades from buyers will appear here when they open your offers.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
