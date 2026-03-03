import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/modal/offer_details_modal.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_screen.dart';
import 'package:next_fi/features/offers/view/widgets/public_offer_tile.dart';
import 'package:next_fi/features/price_chart/model/price_chart_state.dart';
import 'package:next_fi/features/price_chart/view_model/price_chart_vm.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MARKET OFFERS SCREEN — P2P Marketplace
// ─────────────────────────────────────────────────────────────────────────────

class MarketOffersScreen extends StatefulWidget {
  const MarketOffersScreen({super.key, required this.initialType});
  final OfferType initialType;

  @override
  State<MarketOffersScreen> createState() => _MarketOffersScreenState();
}

class _MarketOffersScreenState extends State<MarketOffersScreen>
    with TickerProviderStateMixin {
  final _offersCore = OffersCoreService.I;
  late final PriceChartVM _xlmPriceVm;
  late final PriceChartVM _usdcPriceVm;
  late final VoidCallback _priceListener;

  bool _loading = true;
  String? _error;
  OfferType _selectedType = OfferType.buy;
  List<OfferModel> _offers = const [];
  SeedKeypairVM? _seedVm;
  StellarWalletServices? _stellarSvc;
  String? _lastBoundAddress;
  String? _lastTrustlineCheckedAddress;
  bool _lastHasUsdcTrustline = false;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

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
    _seedVm = context.read<SeedKeypairVM>();
    _stellarSvc = context.read<StellarWalletServices>();
    _lastBoundAddress = _seedVm?.accountId;
    _seedVm?.addListener(_onActiveWalletChanged);
    _selectedType = widget.initialType;

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    _load();
  }

  @override
  void dispose() {
    _seedVm?.removeListener(_onActiveWalletChanged);
    _xlmPriceVm.removeListener(_priceListener);
    _usdcPriceVm.removeListener(_priceListener);
    _xlmPriceVm.dispose();
    _usdcPriceVm.dispose();
    _enterCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _onActiveWalletChanged() {
    final currentAddress = _seedVm?.accountId;
    if (currentAddress == _lastBoundAddress) return;
    _lastBoundAddress = currentAddress;
    _lastTrustlineCheckedAddress = null;
    _load();
  }

  Future<bool> _activeAddressHasUsdcTrustline() async {
    final seedVm = _seedVm ?? context.read<SeedKeypairVM>();
    var accountId = seedVm.accountId?.trim();

    if (accountId == null || accountId.isEmpty) {
      await seedVm.refresh();
      accountId = seedVm.accountId?.trim();
    }
    if (accountId == null || accountId.isEmpty) return false;

    if (_lastTrustlineCheckedAddress == accountId) {
      return _lastHasUsdcTrustline;
    }

    final stellar = _stellarSvc;
    if (stellar == null) return false;
    try {
      final hasTrustline = await stellar.accountService.hasUsdcTrustline(
        accountId,
      );
      _lastTrustlineCheckedAddress = accountId;
      _lastHasUsdcTrustline = hasTrustline;
      return hasTrustline;
    } catch (_) {
      _lastTrustlineCheckedAddress = accountId;
      _lastHasUsdcTrustline = false;
      return false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasUsdcTrustline = await _activeAddressHasUsdcTrustline();
      final offers = await _offersCore.listPublic(
        query: OffersListQuery(type: _selectedType, page: '1', limit: '50'),
      );
      final filteredOffers = offers.where((offer) {
        final asset = offer.asset.trim().toUpperCase();
        if (asset != 'USDC') return true;
        return hasUsdcTrustline;
      }).toList();
      if (!mounted) return;
      setState(() {
        _offers = filteredOffers;
        _loading = false;
      });
      _enterCtrl.forward(from: 0);
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
    HapticFeedback.selectionClick();
    setState(() => _selectedType = type);
    _load();
  }

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

  bool _hasTrustedVmRates() {
    final currency = context.read<CurrencyVM>();
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
    final code = offer.asset.trim().toUpperCase();
    final vm = switch (code) {
      'XLM' => _xlmPriceVm,
      'USDC' => _usdcPriceVm,
      _ => null,
    };
    if (vm == null || vm.fiatCode != fiatCode) return null;
    final live = vm.priceNow;
    if (!live.isFinite || live <= 0) return null;
    final margin = offer.marginPercent ?? 0.0;
    final isMerchantSell = offer.type == OfferType.sell;
    final factor = isMerchantSell
        ? (1.0 + margin / 100.0)
        : (1.0 - margin / 100.0);
    return '${_formatFiat(fiatCode, live * factor)} $fiatCode';
  }

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

  bool _priceLoadingFor(OfferModel offer) {
    if (!_hasTrustedVmRates()) return false;
    final code = offer.asset.trim().toUpperCase();
    final vm = switch (code) {
      'XLM' => _xlmPriceVm,
      'USDC' => _usdcPriceVm,
      _ => null,
    };
    if (vm == null) return false;
    if (vm.fiatCode != offer.fiatCurrency.trim().toUpperCase()) return false;
    return vm.priceNow <= 0;
  }

  bool _offerEnabled(OfferModel offer) {
    if (offer.marketPrice != null && offer.marketPrice! > 0) return true;
    if (!_hasTrustedVmRates()) return true;
    if (_offerEffectivePrice(offer) != null) return true;
    return _priceLoadingFor(offer);
  }

  String _formatFiat(String fiatCode, double value, {int? decimalDigits}) {
    return NumberFormat.simpleCurrency(
      name: fiatCode,
      decimalDigits: decimalDigits,
    ).format(value);
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
            _Header(c: c),
            _PriceStrip(c: c, xlmVm: _xlmPriceVm, usdcVm: _usdcPriceVm),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _TypeToggle(
                c: c,
                selected: _selectedType,
                onChanged: _onTypeChanged,
              ),
            ),

            if (!_loading && _error == null && _offers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Text(
                      '${_offers.length} offer${_offers.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: c.border)),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? _SkeletonList(c: c)
                  : _error != null
                  ? _ErrorState(c: c, error: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: _load,
                      child: _offers.isEmpty
                          ? ListView(
                              children: [
                                _EmptyState(c: c, type: _selectedType),
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
                                  itemCount: _offers.length,
                                  itemBuilder: (_, i) {
                                    final offer = _offers[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: PublicOfferTile(
                                        c: c,
                                        offer: offer,
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

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 0),
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
                  'P2P Marketplace',
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
                  'Trade directly with other users',
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
          _LiveDot(c: c),
        ],
      ),
    );
  }
}

// ─── Live Dot ─────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.c});
  final AppColor c;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
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
          Text(
            'LIVE',
            style: TextStyle(
              color: c.success,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Icon Button ──────────────────────────────────────────────────────────────

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
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, size: 17, color: c.textSecondary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE PRICE STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _PriceStrip extends StatelessWidget {
  const _PriceStrip({
    required this.c,
    required this.xlmVm,
    required this.usdcVm,
  });
  final AppColor c;
  final PriceChartVM xlmVm;
  final PriceChartVM usdcVm;

  @override
  Widget build(BuildContext context) {
    final xlm = xlmVm.priceNow;
    final usdc = usdcVm.priceNow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            _PriceCell(
              c: c,
              token: 'XLM',
              price: (xlm.isFinite && xlm > 0)
                  ? NumberFormat.simpleCurrency(
                      name: xlmVm.fiatCode,
                      decimalDigits: 4,
                    ).format(xlm)
                  : '--',
              fiat: xlmVm.fiatCode,
            ),
            Container(width: 1, height: 28, color: c.border),
            _PriceCell(
              c: c,
              token: 'USDC',
              price: (usdc.isFinite && usdc > 0)
                  ? NumberFormat.simpleCurrency(
                      name: usdcVm.fiatCode,
                      decimalDigits: 4,
                    ).format(usdc)
                  : '--',
              fiat: usdcVm.fiatCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({
    required this.c,
    required this.token,
    required this.price,
    required this.fiat,
  });
  final AppColor c;
  final String token;
  final String price;
  final String fiat;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(
            price,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$token · $fiat',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE TOGGLE (Buy / Sell)
// ─────────────────────────────────────────────────────────────────────────────

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
    final isBuyTab = selected == OfferType.sell;
    final isSellTab = selected == OfferType.buy;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _ToggleOption(
            c: c,
            label: 'BUY',
            icon: Icons.south_west_rounded,
            active: isBuyTab,
            activeColor: c.success,
            onTap: () => onChanged(OfferType.sell),
          ),
          const SizedBox(width: 3),
          _ToggleOption(
            c: c,
            label: 'SELL',
            icon: Icons.north_east_rounded,
            active: isSellTab,
            activeColor: c.error,
            onTap: () => onChanged(OfferType.buy),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : c.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? c.onPrimary : c.textSecondary),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: active ? c.onPrimary : c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.type});
  final AppColor c;
  final OfferType type;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: c.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${type == OfferType.sell ? 'buy' : 'sell'} offers right now',
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
            'Pull down to refresh the marketplace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load offers',
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

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER SKELETON LIST
// ─────────────────────────────────────────────────────────────────────────────

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
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _SkeletonTile(c: c, shimmerAnim: _anim),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.c, required this.shimmerAnim});
  final AppColor c;
  final Animation<double> shimmerAnim;

  Widget _box({required double w, required double h, required double r}) =>
      _MarketShimmerBox(c: c, w: w, h: h, r: r, anim: shimmerAnim);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(w: 42, h: 42, r: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(w: 110, h: 13, r: 4),
                    const SizedBox(height: 6),
                    _box(w: 72, h: 10, r: 3),
                  ],
                ),
              ),
              _box(w: 60, h: 22, r: 7),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: c.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(w: 90, h: 16, r: 4),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _box(w: 56, h: 10, r: 3),
                        const SizedBox(width: 8),
                        _box(w: 56, h: 10, r: 3),
                      ],
                    ),
                  ],
                ),
              ),
              _box(w: 90, h: 36, r: 11),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _box(w: 48, h: 24, r: 7),
              const SizedBox(width: 8),
              _box(w: 64, h: 24, r: 7),
              const Spacer(),
              _box(w: 80, h: 18, r: 5),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketShimmerBox extends StatelessWidget {
  const _MarketShimmerBox({
    required this.c,
    required this.w,
    required this.h,
    required this.r,
    required this.anim,
  });

  final AppColor c;
  final double w;
  final double h;
  final double r;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? c.border.withValues(alpha: 0.52)
        : c.background.withValues(alpha: 0.98);
    final highlight = isDark
        ? c.textPrimary.withValues(alpha: 0.20)
        : c.onPrimary.withValues(alpha: 0.72);

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
                final bandWidth = w * 0.52;
                final travel = w + (bandWidth * 2);
                final left = (travel * anim.value) - bandWidth;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      width: bandWidth,
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
