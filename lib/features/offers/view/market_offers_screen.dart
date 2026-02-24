import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/offer_details_modal.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_screen.dart';
import 'package:next_fi/features/offers/view/widgets/public_offer_tile.dart';
import 'package:next_fi/features/price_chart/model/price_chart_state.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:provider/provider.dart';

class MarketOffersScreen extends StatefulWidget {
  const MarketOffersScreen({super.key, required this.initialType});

  final OfferType initialType;

  @override
  State<MarketOffersScreen> createState() => _MarketOffersScreenState();
}

class _MarketOffersScreenState extends State<MarketOffersScreen> {
  final _offersCore = OffersCoreService.I;
  late final PriceChartVM _xlmPriceVm;
  late final PriceChartVM _usdcPriceVm;
  late final VoidCallback _priceListener;

  bool _loading = true;
  String? _error;
  OfferType _selectedType = OfferType.buy;
  List<OfferModel> _offers = const [];

  @override
  void initState() {
    super.initState();
    final currency = context.read<CurrencyVM>();
    _xlmPriceVm = PriceChartVM(currency, initialToken: PriceToken.xlm);
    _usdcPriceVm = PriceChartVM(currency, initialToken: PriceToken.usdc);
    _priceListener = () {
      if (mounted) setState(() {});
    };
    _xlmPriceVm.addListener(_priceListener);
    _usdcPriceVm.addListener(_priceListener);
    _selectedType = widget.initialType;
    _load();
  }

  @override
  void dispose() {
    _xlmPriceVm.removeListener(_priceListener);
    _usdcPriceVm.removeListener(_priceListener);
    _xlmPriceVm.dispose();
    _usdcPriceVm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await _offersCore.listPublic(
        query: OffersListQuery(
          type: _selectedType,
          page: '1',
          limit: '50',
        ),
      );
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      showFloatingSnackBar(
        context,
        message: 'Failed to load marketplace offers.',
        type: SnackBarType.error,
        position: SnackBarPosition.top,
      );
    }
  }

  void _onTypeChanged(OfferType type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _load();
  }

  Future<void> _openOfferDetails(OfferModel offer) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferDetailsModal(
        offer: offer,
        marketPrice: _offerEffectivePrice(offer),
        onTradeNow: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TradeScreen(
                offer: offer,
                marketPrice: _rawPriceForAsset(offer.asset),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns the effective offer price as a formatted string.
  ///
  /// Priority:
  ///  1. `offer.marketPrice` — the price the merchant explicitly set for this offer.
  ///  2. Live market price ± margin — only when the offer fiat matches the user's
  ///     selected fiat so the conversion is valid.
  String? _offerEffectivePrice(OfferModel offer) {
    final fiatCode = offer.fiatCurrency.trim().toUpperCase();
    final sym = fiatSymbol(fiatCode);

    // 1. Prefer the offer's own stored price (already reflects merchant margin).
    if (offer.marketPrice != null && offer.marketPrice! > 0) {
      return '${fmtFiat(sym, offer.marketPrice!)} $fiatCode';
    }

    // 2. Fall back: live price ± margin (only when fiat currencies match).
    final code = offer.asset.trim().toUpperCase();
    final vm = switch (code) {
      'XLM' => _xlmPriceVm,
      'USDC' => _usdcPriceVm,
      _ => null,
    };
    if (vm == null) return null;
    if (vm.fiatCode != fiatCode) return null;

    final live = vm.priceNow;
    if (!live.isFinite || live <= 0) return null;

    final margin = offer.marginPercent ?? 0.0;
    final isMerchantSell = offer.type == OfferType.sell;
    final factor =
        isMerchantSell ? (1.0 + margin / 100.0) : (1.0 - margin / 100.0);
    return '${fmtFiat(vm.fiatSym, live * factor)} $fiatCode';
  }

  /// Returns the raw numeric live price for use in fiat↔crypto calculations in TradeScreen.
  double? _rawPriceForAsset(String assetCode) {
    final code = assetCode.trim().toUpperCase();
    final vm = switch (code) {
      'XLM' => _xlmPriceVm,
      'USDC' => _usdcPriceVm,
      _ => null,
    };
    if (vm == null) return null;
    final p = vm.priceNow;
    return (p.isFinite && p > 0) ? p : null;
  }

  bool get _priceLoading =>
      _xlmPriceVm.priceNow <= 0 && _usdcPriceVm.priceNow <= 0;

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
          'P2P Marketplace',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _selectedType == OfferType.sell
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: c.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedType == OfferType.sell
                          ? 'P2P • Browse active BUY offers'
                          : 'P2P • Browse active SELL offers',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _TypeSwitch(
                c: c, selected: _selectedType, onChanged: _onTypeChanged),
          ),
          Expanded(
            child: _loading
                ? _SkeletonOfferList(c: c)
                : _error != null
                    ? _ErrorState(c: c, error: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _offers.isEmpty
                            ? ListView(
                                children: [_EmptyState(c: c, type: _selectedType)])
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 6, 0, 24),
                                itemCount: _offers.length,
                                itemBuilder: (_, i) {
                                  final offer = _offers[i];
                                  return PublicOfferTile(
                                    c: c,
                                    offer: offer,
                                    marketPrice: _offerEffectivePrice(offer),
                                    priceLoading: _priceLoading,
                                    onTap: () => _openOfferDetails(offer),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch(
      {required this.c, required this.selected, required this.onChanged});

  final AppColor c;
  final OfferType selected;
  final ValueChanged<OfferType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _TypeBtn(
              c: c,
              label: 'BUY',
              selected: selected == OfferType.sell,
              onTap: () => onChanged(OfferType.sell)),
          const SizedBox(width: 4),
          _TypeBtn(
              c: c,
              label: 'SELL',
              selected: selected == OfferType.buy,
              onTap: () => onChanged(OfferType.buy)),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn(
      {required this.c,
      required this.label,
      required this.selected,
      required this.onTap});

  final AppColor c;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : c.textSecondary,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(
      {required this.c, required this.error, required this.onRetry});

  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: c.error, size: 30),
            const SizedBox(height: 10),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            AppOutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.type});

  final AppColor c;
  final OfferType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, color: c.textSecondary, size: 28),
            const SizedBox(height: 10),
            Text(
              'No ${type == OfferType.sell ? 'buy' : 'sell'} offers right now',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text('Pull down to refresh the marketplace list.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer Skeleton List ────────────────────────────────────────────────────

class _SkeletonOfferList extends StatefulWidget {
  const _SkeletonOfferList({required this.c});
  final AppColor c;

  @override
  State<_SkeletonOfferList> createState() => _SkeletonOfferListState();
}

class _SkeletonOfferListState extends State<_SkeletonOfferList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final op = (isLight ? 0.09 : 0.05) +
            _anim.value * (isLight ? 0.13 : 0.09);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (_, __) => _SkeletonTile(c: c, isLight: isLight, op: op),
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile(
      {required this.c, required this.isLight, required this.op});

  final AppColor c;
  final bool isLight;
  final double op;

  Widget _box({required double w, required double h, required double r}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: c.border.withOpacity(op),
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: c.border.withOpacity(isLight ? 0.10 : 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _box(w: 42, h: 42, r: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(w: 110, h: 14, r: 4),
                      const SizedBox(height: 5),
                      _box(w: 72, h: 11, r: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _box(w: 52, h: 22, r: 7),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: c.border.withOpacity(op * 0.6)),
            const SizedBox(height: 14),
            // Price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(w: 88, h: 17, r: 4),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _box(w: 56, h: 12, r: 3),
                          const SizedBox(width: 6),
                          _box(w: 56, h: 12, r: 3),
                        ],
                      ),
                    ],
                  ),
                ),
                _box(w: 96, h: 38, r: 12),
              ],
            ),
            const SizedBox(height: 12),
            // Bottom row
            Row(
              children: [
                _box(w: 44, h: 26, r: 8),
                const SizedBox(width: 8),
                _box(w: 60, h: 26, r: 8),
                const Spacer(),
                _box(w: 88, h: 20, r: 5),
                const SizedBox(width: 10),
                _box(w: 30, h: 30, r: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
