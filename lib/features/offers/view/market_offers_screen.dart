import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/modal/offer_details_modal.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_screen.dart';
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
    final c = AppColor.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferDetailsModal(
        offer: offer,
        marketPrice: _marketPriceForAsset(offer.asset),
        onTradeNow: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TradeScreen(offer: offer),
            ),
          );
        },
      ),
    );
  }

  String? _marketPriceForAsset(String assetCode) {
    final code = assetCode.trim().toUpperCase();
    final vm = switch (code) {
      'XLM' => _xlmPriceVm,
      'USDC' => _usdcPriceVm,
      _ => null,
    };
    if (vm == null) return null;
    final p = vm.priceNow;
    if (!p.isFinite || p <= 0) return null;
    return '${fmtFiat(vm.fiatSym, p)} ${vm.fiatCode}';
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
                      _selectedType == OfferType.buy
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: c.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedType == OfferType.buy
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
              c: c,
              selected: _selectedType,
              onChanged: _onTypeChanged,
            ),
          ),
          Expanded(
            child: _loading
                ? const PageLoader(label: 'Loading offers...')
                : _error != null
                    ? _ErrorState(c: c, error: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _offers.isEmpty
                            ? ListView(children: [
                                _EmptyState(c: c, type: _selectedType),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                itemCount: _offers.length,
                                itemBuilder: (_, i) {
                                  final offer = _offers[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _PublicOfferTile(
                                      c: c,
                                      offer: offer,
                                      marketPrice: _marketPriceForAsset(
                                        offer.asset,
                                      ),
                                      onTap: () => _openOfferDetails(offer),
                                    ),
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
  const _TypeSwitch({
    required this.c,
    required this.selected,
    required this.onChanged,
  });

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
            selected: selected == OfferType.buy,
            onTap: () => onChanged(OfferType.buy),
          ),
          const SizedBox(width: 4),
          _TypeBtn(
            c: c,
            label: 'SELL',
            selected: selected == OfferType.sell,
            onTap: () => onChanged(OfferType.sell),
          ),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : c.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicOfferTile extends StatelessWidget {
  const _PublicOfferTile({
    required this.c,
    required this.offer,
    required this.marketPrice,
    required this.onTap,
  });

  final AppColor c;
  final OfferModel offer;
  final String? marketPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeText = offer.type == OfferType.buy ? 'BUY' : 'SELL';
    final typeColor =
        offer.type == OfferType.buy ? const Color(0xFF0EA968) : c.primary;
    final statusText = offer.status?.name.toUpperCase() ?? 'UNKNOWN';
    final livePriceText = marketPrice == null ? 'No live price' : 'Live $marketPrice';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                offer.type == OfferType.buy
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                size: 18,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _InfoBadge(
                        c: c,
                        label: typeText,
                        fg: typeColor,
                        bg: typeColor.withOpacity(0.12),
                        border: typeColor.withOpacity(0.25),
                      ),
                      _InfoBadge(
                        c: c,
                        label: statusText,
                        fg: c.textPrimary,
                        bg: c.background.withOpacity(0.45),
                        border: c.border.withOpacity(0.22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${offer.asset}/${offer.fiatCurrency}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Min ${offer.minAmount ?? '-'} · Max ${offer.maxAmount ?? '-'}',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _InfoBadge(
                    c: c,
                    label: livePriceText,
                    fg: marketPrice == null ? c.textSecondary : c.primary,
                    bg: marketPrice == null
                        ? c.background.withOpacity(0.42)
                        : c.primary.withOpacity(0.12),
                    border: marketPrice == null
                        ? c.border.withOpacity(0.22)
                        : c.primary.withOpacity(0.28),
                    icon: marketPrice == null
                        ? Icons.info_outline_rounded
                        : Icons.bolt_rounded,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: c.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.c,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    this.icon,
  });

  final AppColor c;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: c.error, size: 30),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            AppOutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
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
              'No ${type == OfferType.buy ? 'buy' : 'sell'} offers right now',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pull down to refresh the marketplace list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
