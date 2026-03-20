import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/empty_state/empty_state.dart';
import 'package:next_fi/core/widgets/modal/marketplace_filters_modal.dart';
import 'package:next_fi/core/widgets/modal/offer_details_modal.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/offers/presentation/screens/trade_screen.dart';
import 'package:next_fi/features/offers/presentation/viewmodels/market_offers_controller.dart';
import 'package:next_fi/features/offers/presentation/widgets/public_offer_tile.dart';
import 'package:next_fi/features/price_chart/presentation/viewmodels/price_chart_vm.dart';
import 'package:next_fi/app/viewmodels/asset_vm.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/offers/models/offers_models.dart';

abstract class _T {
  static const screenTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static const screenSubtitle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    height: 1.0,
  );

  static const pulsePair = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const pulsePrice = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const pulseChange = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const toggleLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    height: 1.0,
  );

  static const offerCount = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const errorTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const errorBody = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const retryButton = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.0,
  );

  static const pulseTab = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.0,
  );
}

class MarketOffersScreen extends ConsumerStatefulWidget {
  const MarketOffersScreen({super.key, required this.initialType});
  final OfferType initialType;

  @override
  ConsumerState<MarketOffersScreen> createState() => _MarketOffersScreenState();
}

class _MarketOffersScreenState extends ConsumerState<MarketOffersScreen>
    with TickerProviderStateMixin {
  late final AssetVM _assetVm;
  late final PriceChartVM _xlmPriceVm;
  late final PriceChartVM _usdcPriceVm;
  late final VoidCallback _priceListener;
  ProviderSubscription? _seedSubscription;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    final currency = ref.read(currencyVmProvider);
    final config = ref.read(appConfigProvider);

    _assetVm = AssetVM(
      currency,
      isTestnet: config.isTestnet,
      usdcIssuer: config.usdcIssuer,
    );
    _xlmPriceVm = PriceChartVM(currency, _assetVm, initialAssetKey: 'XLM');
    _usdcPriceVm = PriceChartVM(currency, _assetVm, initialAssetKey: 'USDC');
    _priceListener = () {
      if (mounted) setState(() {});
    };
    _xlmPriceVm.addListener(_priceListener);
    _usdcPriceVm.addListener(_priceListener);
    _assetVm.addListener(_priceListener);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
    _seedSubscription = ref.listenManual(seedKeypairProvider, (previous, next) {
      if (previous?.accountId == next.accountId) return;
      ref
          .read(marketOffersControllerProvider(widget.initialType).notifier)
          .handleActiveWalletChanged(next.accountId);
    });
  }

  @override
  void dispose() {
    _seedSubscription?.close();
    _xlmPriceVm.removeListener(_priceListener);
    _usdcPriceVm.removeListener(_priceListener);
    _assetVm.removeListener(_priceListener);
    _xlmPriceVm.dispose();
    _usdcPriceVm.dispose();
    _assetVm.dispose();
    _enterCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(OfferType currentType, OfferType nextType) {
    if (currentType == nextType) return;
    HapticFeedback.selectionClick();
    ref
        .read(marketOffersControllerProvider(widget.initialType).notifier)
        .setOfferType(nextType);
  }

  Future<void> _openFilters(MarketOfferFilters filters) async {
    final screenState = ref.read(
      marketOffersControllerProvider(widget.initialType),
    );
    final result = await showMarketplaceFiltersModal(
      context,
      initialFilters: filters,
      paymentMethods: screenState.paymentMethods,
    );

    if (result == null || result == filters) return;
    await ref
        .read(marketOffersControllerProvider(widget.initialType).notifier)
        .applyFilters(result);
  }

  bool _hasTrustedVmRates() {
    final currency = ref.read(currencyVmProvider);
    return !currency.loading &&
        !currency.ratesUnavailable &&
        !currency.usingFallbackRates;
  }

  String? _offerEffectivePrice(OfferModel offer) {
    final fiatCode = offer.fiatCurrency.trim().toUpperCase();
    if (offer.marketPrice != null && offer.marketPrice! > 0) {
      return '${_formatFiat(fiatCode, offer.marketPrice!)} $fiatCode';
    }
    if (!_hasTrustedVmRates()) return null;
    final asset = _assetVm.findAsset(offer.asset);
    final currency = ref.read(currencyVmProvider);
    if (asset == null || currency.fiatCode != fiatCode) return null;
    final live = currency.assetUnitPriceFiat(asset);
    if (!live.isFinite || live <= 0) return null;
    final margin = offer.marginPercent ?? 0.0;
    final isMerchantSell = offer.type == OfferType.sell;
    final factor = isMerchantSell
        ? (1.0 + margin / 100.0)
        : (1.0 - margin / 100.0);
    return '${_formatFiat(fiatCode, live * factor)} $fiatCode';
  }

  double? _rawPriceForAsset(String assetCode) {
    final asset = _assetVm.findAsset(assetCode);
    if (asset == null) return null;
    final p = ref.read(currencyVmProvider).assetUnitPriceFiat(asset);
    return (p.isFinite && p > 0) ? p : null;
  }

  bool _priceLoadingFor(OfferModel offer) {
    if (!_hasTrustedVmRates()) return false;
    final asset = _assetVm.findAsset(offer.asset);
    final currency = ref.read(currencyVmProvider);
    if (asset == null) return false;
    if (currency.fiatCode != offer.fiatCurrency.trim().toUpperCase())
      return false;
    return currency.assetUnitPriceFiat(asset) <= 0;
  }

  bool _offerEnabled(OfferModel offer) {
    if (offer.marketPrice != null && offer.marketPrice! > 0) return true;
    if (!_hasTrustedVmRates()) return true;
    if (_offerEffectivePrice(offer) != null) return true;
    return _priceLoadingFor(offer);
  }

  String _formatFiat(String fiatCode, double value, {int? decimalDigits}) =>
      NumberFormat.simpleCurrency(
        name: fiatCode,
        decimalDigits: decimalDigits,
      ).format(value);

  Future<void> _openOfferDetails(OfferModel offer) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
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

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(
      marketOffersControllerProvider(widget.initialType),
    );
    ref.listen(marketOffersControllerProvider(widget.initialType), (
      previous,
      next,
    ) {
      if (previous?.error != next.error && next.error != null) {
        showFloatingSnackBar(
          context,
          message: 'Failed to load marketplace offers.',
          type: SnackBarType.error,
          position: SnackBarPosition.top,
        );
      }
      final offersChanged = previous?.offers != next.offers;
      if (offersChanged && !next.loading && next.error == null) {
        _enterCtrl.forward(from: 0);
      }
    });
    final c = AppColor.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(c: c),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MarketPulseStrip(
                c: c,
                xlmVm: _xlmPriceVm,
                usdcVm: _usdcPriceVm,
                assetVm: _assetVm,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TypeToggle(
                c: c,
                selected: screenState.selectedType,
                onChanged: (OfferType value) =>
                    _onTypeChanged(screenState.selectedType, value),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FilterBar(
                c: c,
                activeCount: screenState.filters.activeCount,
                summary: screenState.filters.summary(
                  screenState.paymentMethods,
                ),
                onTap: () => _openFilters(screenState.filters),
              ),
            ),
            if (!screenState.loading &&
                screenState.error == null &&
                screenState.offers.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OfferCountRow(c: c, count: screenState.offers.length),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: screenState.loading
                  ? _SkeletonList(c: c)
                  : screenState.error != null
                  ? _ErrorState(
                      c: c,
                      error: screenState.error!,
                      onRetry: () => ref
                          .read(
                            marketOffersControllerProvider(
                              widget.initialType,
                            ).notifier,
                          )
                          .load(),
                    )
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: () => ref
                          .read(
                            marketOffersControllerProvider(
                              widget.initialType,
                            ).notifier,
                          )
                          .load(),
                      child: screenState.offers.isEmpty
                          ? ListView(
                              children: [
                                _EmptyState(
                                  c: c,
                                  type: screenState.selectedType,
                                ),
                              ],
                            )
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: SlideTransition(
                                position: _slideAnim,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    32,
                                  ),
                                  itemCount: screenState.offers.length,
                                  itemBuilder: (_, i) {
                                    final offer = screenState.offers[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: PublicOfferTile(
                                        c: c,
                                        offer: offer,
                                        assetVm: _assetVm,
                                        marketPrice: _offerEffectivePrice(
                                          offer,
                                        ),
                                        priceLoading: _priceLoadingFor(offer),
                                        enabled: _offerEnabled(offer),
                                        shimmerAnim: _shimmerAnim,
                                        onTap: () => _openOfferDetails(offer),
                                      ),
                                    );
                                  },
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

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop) ...[_BackButton(c: c), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'P2P Marketplace',
                  style: _T.screenTitle.copyWith(color: c.textPrimary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Text(
                  'Trade directly with other users',
                  style: _T.screenSubtitle.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _LiveBadge(c: c),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.border),
      ),
      child: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 15,
        color: c.textSecondary,
      ),
    ),
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: c.success.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.success.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('LIVE', style: _T.label.copyWith(color: c.success)),
      ],
    ),
  );
}

class _OfferCountRow extends StatelessWidget {
  const _OfferCountRow({required this.c, required this.count});
  final AppColor c;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$count offer${count == 1 ? '' : 's'}',
        style: _T.offerCount.copyWith(color: c.textSecondary),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: c.border)),
    ],
  );
}

class _MarketPulseStrip extends StatelessWidget {
  const _MarketPulseStrip({
    required this.c,
    required this.xlmVm,
    required this.usdcVm,
    required this.assetVm,
  });
  final AppColor c;
  final PriceChartVM xlmVm;
  final PriceChartVM usdcVm;
  final AssetVM assetVm;

  @override
  Widget build(BuildContext context) {
    final xlm = xlmVm.priceNow;
    final usdc = usdcVm.priceNow;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              _PulseCell(
                c: c,
                logoUrl: assetVm.logoFor('xlm'),
                token: 'XLM',
                fiat: xlmVm.fiatCode,
                price: (xlm.isFinite && xlm > 0)
                    ? NumberFormat.simpleCurrency(
                        name: xlmVm.fiatCode,
                        decimalDigits: 4,
                      ).format(xlm)
                    : '--',
                changePercent: assetVm.findAsset('xlm')?.priceChangePercent24h,
              ),
              Container(
                width: 1,
                height: 52,
                color: c.border.withValues(alpha: 0.5),
              ),
              _PulseCell(
                c: c,
                logoUrl: assetVm.logoFor('usdc'),
                token: 'USDC',
                fiat: usdcVm.fiatCode,
                price: (usdc.isFinite && usdc > 0)
                    ? NumberFormat.simpleCurrency(
                        name: usdcVm.fiatCode,
                        decimalDigits: 4,
                      ).format(usdc)
                    : '--',
                changePercent: assetVm.findAsset('usdc')?.priceChangePercent24h,
              ),
            ],
          ),
        ),
        Positioned(
          top: -10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.border.withValues(alpha: 0.7)),
              ),
              child: Text(
                'MARKET PULSE',
                style: _T.pulseTab.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseCell extends StatelessWidget {
  const _PulseCell({
    required this.c,
    required this.logoUrl,
    required this.token,
    required this.fiat,
    required this.price,
    required this.changePercent,
  });
  final AppColor c;
  final String logoUrl;
  final String token;
  final String fiat;
  final String price;
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    final pct = changePercent;
    final isPositive = pct == null || pct >= 0;
    final pctColor = isPositive ? c.success : c.error;
    final pctLabel = (pct == null || pct.isNaN)
        ? null
        : '${isPositive ? '+' : ''}${pct.toStringAsFixed(2)}%';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.background,
                  border: Border.all(color: c.border),
                ),
                child: ClipOval(
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        token[0],
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$token / $fiat',
                    style: _T.pulsePair.copyWith(color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: _T.pulsePrice.copyWith(color: c.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (pctLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      pctLabel,
                      style: _T.pulseChange.copyWith(color: pctColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.c,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final OfferType selected;
  final ValueChanged<OfferType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBuy = selected == OfferType.sell;
    final isSell = selected == OfferType.buy;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          _ToggleTab(
            c: c,
            label: 'BUY',
            icon: Icons.south_west_rounded,
            active: isBuy,
            activeColor: c.success,
            onTap: () => onChanged(OfferType.sell),
          ),
          const SizedBox(width: 4),
          _ToggleTab(
            c: c,
            label: 'SELL',
            icon: Icons.north_east_rounded,
            active: isSell,
            activeColor: c.error,
            onTap: () => onChanged(OfferType.buy),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.c,
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });
  final AppColor c;
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? c.onPrimary : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: _T.toggleLabel.copyWith(
                color: active ? c.onPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.c,
    required this.activeCount,
    required this.summary,
    required this.onTap,
  });

  final AppColor c;
  final int activeCount;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? c.primary.withValues(alpha: 0.12)
                    : c.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: activeCount > 0 ? c.primary : c.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeCount > 0
                        ? 'Filters Applied ($activeCount)'
                        : 'Marketplace Filters',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_right_rounded, color: c.textSecondary),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: EmptyState.noData(
      context: context,
      title: 'No ${type == OfferType.sell ? 'buy' : 'sell'} offers right now',
      message: 'Pull down to refresh the marketplace.',
      compact: true,
    ),
  );
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
              border: Border.all(color: c.error.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            "Couldn't load offers",
            style: _T.errorTitle.copyWith(color: c.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: _T.errorBody.copyWith(color: c.textSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Try again',
                style: _T.retryButton.copyWith(color: c.onPrimary),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList({required this.c});
  final AppColor c;

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.linear,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SkeletonTile(c: c, anim: _anim),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.c, required this.anim});
  final AppColor c;
  final Animation<double> anim;

  Widget _box(double w, double h, double r) =>
      _ShimBox(c: c, w: w, h: h, r: r, anim: anim);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.border.withValues(alpha: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _box(72, 20, 5),
        const SizedBox(height: 10),
        Row(
          children: [
            _box(44, 44, 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _box(120, 12, 4),
                  const SizedBox(height: 6),
                  _box(80, 10, 3),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            _box(36, 36, 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _box(100, 16, 4),
                  const SizedBox(height: 6),
                  _box(64, 11, 4),
                ],
              ),
            ),
            _box(76, 36, 10),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        _box(140, 11, 3),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _box(double.infinity, 40, 10)),
            const SizedBox(width: 8),
            _box(100, 40, 10),
          ],
        ),
      ],
    ),
  );
}

class _ShimBox extends StatelessWidget {
  const _ShimBox({
    required this.c,
    required this.w,
    required this.h,
    required this.r,
    required this.anim,
  });
  final AppColor c;
  final double w, h, r;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? c.border.withValues(alpha: 0.5)
        : c.background.withValues(alpha: 0.98);
    final highlight = isDark
        ? c.textPrimary.withValues(alpha: 0.16)
        : c.onPrimary.withValues(alpha: 0.65);
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: base),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) {
                final band = w * 0.5;
                final travel = w + band * 2;
                final left = travel * anim.value - band;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: band,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              highlight.withValues(alpha: 0),
                              highlight,
                              highlight.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
