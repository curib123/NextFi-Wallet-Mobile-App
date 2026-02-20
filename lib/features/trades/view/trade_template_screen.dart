import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/showFiatPickerBottomSheet.dart';
import 'package:next_fi/features/merchant_offers/view/merchant_offers_screen.dart';
import 'package:next_fi/features/merchant_request/view/merchant_request_screen.dart';
import 'package:next_fi/features/merchant_trades/view/merchant_trades_screen.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';
import 'package:provider/provider.dart';

import 'trade_offer_detail_screen.dart';

enum TradeTemplateMode { buy, sell }

class TradeTemplateScreen extends StatefulWidget {
  const TradeTemplateScreen({super.key, required this.mode});

  final TradeTemplateMode mode;

  @override
  State<TradeTemplateScreen> createState() => _TradeTemplateScreenState();
}

class _TradeTemplateScreenState extends State<TradeTemplateScreen> {
  final _auth = AuthService();
  final _offers = OffersCoreService.I;
  final _profile = ProfileCoreService.I;
  final _trades = TradesCoreService.I;
  final _searchCtrl = TextEditingController();

  final NumberFormat _money = NumberFormat.currency(
    symbol: '',
    decimalDigits: 2,
  );

  OfferAsset _asset = OfferAsset.usdc;
  bool _recommended = true;
  bool _loading = true;
  bool _merchantLoading = true;
  bool _isMerchant = false;
  int _tradeInboxPending = 0;
  String? _currentUserId;
  String? _error;
  List<OfferModel> _items = const [];
  Timer? _inboxRefreshTimer;

  bool get _isBuy => widget.mode == TradeTemplateMode.buy;
  String get _title => _isBuy ? 'Buy Crypto' : 'Sell Crypto';
  String get _subtitle => _isBuy
      ? 'Browse merchant SELL offers. You pay fiat, merchant releases crypto to you.'
      : 'Browse merchant BUY offers. You send crypto, merchant pays you fiat.';
  String get _roleLabel => _isBuy ? 'Merchant: Seller' : 'Merchant: Buyer';
  OfferType get _targetOfferType => _isBuy ? OfferType.sell : OfferType.buy;

  @override
  void initState() {
    super.initState();
    _loadMerchantStatus();
    _loadOffers();
  }

  @override
  void dispose() {
    _inboxRefreshTimer?.cancel();
    _inboxRefreshTimer = null;
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final query = OffersQuery(
      type: _targetOfferType,
      asset: _asset,
      fiatCurrency: context.read<CurrencyVM>().fiat.toUpperCase(),
      q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      page: 1,
      limit: 100,
    );

    try {
      final items = _recommended
          ? await _offers.listRecommendedOffers(query)
          : await _offers.listPublicOffers(query);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (_recommended) {
        try {
          final fallback = await _offers.listPublicOffers(query);
          if (!mounted) return;
          setState(() {
            _items = fallback;
            _recommended = false;
            _loading = false;
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMerchantStatus() async {
    try {
      try {
        _currentUserId = (await _auth.currentUser).id;
      } catch (_) {
        _currentUserId = null;
      }
      final me = await _profile.getMe();
      if (!mounted) return;
      setState(() {
        _isMerchant = me?.isMerchant == true;
        _merchantLoading = false;
      });
      if (_isMerchant) {
        await _refreshTradeInboxPendingCount();
        _inboxRefreshTimer?.cancel();
        _inboxRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
          _refreshTradeInboxPendingCount();
        });
      } else {
        if (_tradeInboxPending != 0 && mounted) {
          setState(() => _tradeInboxPending = 0);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _merchantLoading = false;
        _tradeInboxPending = 0;
      });
    }
  }

  Future<void> _refreshTradeInboxPendingCount() async {
    if (!_isMerchant) return;
    try {
      final me = _currentUserId?.trim() ?? '';
      final trades = await _trades.listSellerTrades(
        const TradesQuery(page: 1, limit: 100),
      );
      var pending = 0;
      for (final trade in trades) {
        if (trade.isFinalStatus || trade.messages.isEmpty) continue;
        final last = trade.messages.last;
        if (me.isEmpty ||
            (last.senderId.trim().isNotEmpty && last.senderId != me)) {
          pending++;
        }
      }
      if (!mounted) return;
      if (pending != _tradeInboxPending) {
        setState(() => _tradeInboxPending = pending);
      }
    } catch (_) {
      if (!mounted) return;
      if (_tradeInboxPending != 0) {
        setState(() => _tradeInboxPending = 0);
      }
    }
  }

  Future<void> _openOffer(OfferModel offer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TradeOfferDetailScreen(mode: widget.mode, offer: offer),
      ),
    );
    if (changed == true && mounted) {
      await _loadOffers();
    }
  }

  String _priceLabel(OfferModel offer) {
    if (offer.priceType == OfferPriceType.fixed && offer.fixedPrice != null) {
      return '${_money.format(offer.fixedPrice)} ${offer.fiatCurrency}';
    }
    if (offer.priceType == OfferPriceType.floating &&
        offer.marginPercent != null) {
      return 'Market ${offer.marginPercent! >= 0 ? '+' : ''}${offer.marginPercent!.toStringAsFixed(2)}%';
    }
    return 'Price not available';
  }

  void _openMerchantOffers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MerchantOffersScreen()));
  }

  Future<void> _openMerchantTrades() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MerchantTradesScreen()));
    if (!mounted) return;
    await _refreshTradeInboxPendingCount();
  }

  void _openMerchantRequest() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MerchantRequestScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final fiat = context.watch<CurrencyVM>().fiat.toUpperCase();
    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border.withOpacity(0.3)),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (_isBuy ? c.success : c.warning)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isBuy ? 'BUY CRYPTO' : 'SELL CRYPTO',
                            style: TextStyle(
                              color: _isBuy ? c.success : c.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _roleLabel,
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.6,
                        height: 1.4,
                      ),
                    ),
                    if (!_isBuy) ...[
                      const SizedBox(height: 12),
                      if (_merchantLoading)
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checking merchant access...',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12.3,
                              ),
                            ),
                          ],
                        )
                      else if (_isMerchant)
                        Row(
                          children: [
                            Expanded(
                              child: AppElevatedButton.icon(
                                onPressed: _openMerchantOffers,
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Create Offer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppOutlinedButton.icon(
                                onPressed: _openMerchantTrades,
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                ),
                                label: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Trade Inbox'),
                                    if (_tradeInboxPending > 0) ...[
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.error.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          border: Border.all(
                                            color: c.error.withOpacity(0.24),
                                          ),
                                        ),
                                        child: Text(
                                          _tradeInboxPending > 99
                                              ? '99+'
                                              : _tradeInboxPending.toString(),
                                          style: TextStyle(
                                            color: c.error,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.textPrimary,
                                  side: BorderSide(
                                    color: c.border.withOpacity(0.35),
                                  ),
                                  minimumSize: const Size.fromHeight(42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                          decoration: BoxDecoration(
                            color: c.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c.warning.withOpacity(0.24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 16,
                                color: c.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Apply as merchant to create your own offers.',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 12.2,
                                  ),
                                ),
                              ),
                              AppTextButton(
                                onPressed: _openMerchantRequest,
                                style: TextButton.styleFrom(
                                  foregroundColor: c.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Request'),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _loadOffers(),
                            decoration: InputDecoration(
                              hintText: 'Search offers',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: c.textSecondary.withOpacity(0.7),
                              ),
                              filled: true,
                              fillColor: c.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: BorderSide(
                                  color: c.border.withOpacity(0.25),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: BorderSide(
                                  color: c.border.withOpacity(0.22),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: BorderSide(
                                  color: c.primary.withOpacity(0.4),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final old = context.read<CurrencyVM>().fiat;
                            await showFiatPickerBottomSheet(context);
                            if (!mounted) return;
                            if (context.read<CurrencyVM>().fiat != old) {
                              _loadOffers();
                            }
                          },
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: c.background,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: c.border.withOpacity(0.22),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fiat,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 16,
                                  color: c.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _AssetChip(
                          selected: _asset == OfferAsset.usdc,
                          label: 'USDC',
                          c: c,
                          onTap: () {
                            setState(() => _asset = OfferAsset.usdc);
                            _loadOffers();
                          },
                        ),
                        const SizedBox(width: 8),
                        _AssetChip(
                          selected: _asset == OfferAsset.xlm,
                          label: 'XLM',
                          c: c,
                          onTap: () {
                            setState(() => _asset = OfferAsset.xlm);
                            _loadOffers();
                          },
                        ),
                        const Spacer(),
                        AppTextButton.icon(
                          onPressed: () {
                            setState(() => _recommended = !_recommended);
                            _loadOffers();
                          },
                          icon: Icon(
                            _recommended
                                ? LucideIcons.sparkles
                                : LucideIcons.listFilter,
                            size: 14,
                          ),
                          label: Text(_recommended ? 'Recommended' : 'Public'),
                          style: TextButton.styleFrom(
                            foregroundColor: c.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            backgroundColor: c.primary.withOpacity(0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Row(
                children: [
                  Text(
                    'OFFERS',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _TradeError(error: _error!, c: c, onRetry: _loadOffers)
                  : _items.isEmpty
                  ? _TradeEmpty(c: c)
                  : RefreshIndicator(
                      onRefresh: _loadOffers,
                      color: c.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        itemBuilder: (_, i) {
                          final offer = _items[i];
                          return _OfferCard(
                            offer: offer,
                            c: c,
                            priceLabel: _priceLabel(offer),
                            onTap: () => _openOffer(offer),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: _items.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        _title,
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
          tooltip: 'Refresh offers',
          onPressed: _loading ? null : _loadOffers,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _AssetChip extends StatelessWidget {
  const _AssetChip({
    required this.selected,
    required this.label,
    required this.c,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final AppColor c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.primary : c.border.withOpacity(0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.c,
    required this.priceLabel,
    required this.onTap,
  });

  final OfferModel offer;
  final AppColor c;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final methods = offer.paymentMethods
        .map((e) => e.name.trim().isEmpty ? e.code : e.name)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final methodsLabel = methods.isEmpty
        ? 'No methods listed'
        : methods.take(3).join(' | ');

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '${offerAssetToApi(offer.asset)}/${offer.fiatCurrency}',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  LucideIcons.shieldCheck,
                  size: 14,
                  color: c.success.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Escrow',
                  style: TextStyle(
                    color: c.success,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              priceLabel,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Limits: ${offer.minAmount.toStringAsFixed(2)} - ${offer.maxAmount.toStringAsFixed(2)} ${offer.fiatCurrency}',
              style: TextStyle(color: c.textSecondary, fontSize: 12.4),
            ),
            const SizedBox(height: 2),
            Text(
              'Payment window: ${offer.paymentWindow} mins',
              style: TextStyle(color: c.textSecondary, fontSize: 12.4),
            ),
            const SizedBox(height: 8),
            Text(
              methodsLabel,
              style: TextStyle(
                color: c.textPrimary.withOpacity(0.8),
                fontSize: 12.2,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: AppElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('View Offer'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
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
    );
  }
}

class _TradeError extends StatelessWidget {
  const _TradeError({
    required this.error,
    required this.c,
    required this.onRetry,
  });

  final String error;
  final AppColor c;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: c.error, size: 24),
            const SizedBox(height: 8),
            Text(
              'Failed to load offers',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            AppOutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeEmpty extends StatelessWidget {
  const _TradeEmpty({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.listX, color: c.textSecondary, size: 24),
            const SizedBox(height: 8),
            Text(
              'No offers found',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing asset, fiat, or search keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
