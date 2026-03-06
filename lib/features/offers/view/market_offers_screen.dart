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
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/seed_keypair_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY TOKENS  (mirrors public_offer_tile.dart _T)
// ─────────────────────────────────────────────────────────────────────────────

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

  static const emptyTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const emptyBody = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
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
  final _paymentCore = PaymentMethodAndAccountsCoreService.I;

  late final AssetVM _assetVm;
  late final PriceChartVM _xlmPriceVm;
  late final PriceChartVM _usdcPriceVm;
  late final VoidCallback _priceListener;

  bool _loading = true;
  String? _error;
  OfferType _selectedType = OfferType.buy;
  List<OfferModel> _offers = const [];
  List<PaymentMethodModel> _paymentMethods = const [];
  _MarketOfferFilters _filters = const _MarketOfferFilters();

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

    _assetVm = AssetVM(currency);
    _xlmPriceVm = PriceChartVM(currency, initialToken: PriceToken.xlm);
    _usdcPriceVm = PriceChartVM(currency, initialToken: PriceToken.usdc);
    _priceListener = () {
      if (mounted) setState(() {});
    };
    _xlmPriceVm.addListener(_priceListener);
    _usdcPriceVm.addListener(_priceListener);
    _assetVm.addListener(_priceListener);

    _seedVm = context.read<SeedKeypairVM>();
    _stellarSvc = context.read<StellarWalletServices>();
    _lastBoundAddress = _seedVm?.accountId;
    _seedVm?.addListener(_onActiveWalletChanged);
    _selectedType = widget.initialType;

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _enterCtrl, curve: Curves.easeOutCubic));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _shimmerAnim =
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);

    _load();
  }

  @override
  void dispose() {
    _seedVm?.removeListener(_onActiveWalletChanged);
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
      final has = await stellar.accountService.hasUsdcTrustline(accountId);
      _lastTrustlineCheckedAddress = accountId;
      _lastHasUsdcTrustline = has;
      return has;
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
      final hasUsdc = await _activeAddressHasUsdcTrustline();
      final paymentMethods = await _paymentCore.listPaymentMethods(
        activeOnly: true,
      );
      final offers = await _offersCore.listPublic(
        query: _filters.toQuery(type: _selectedType),
      );
      final filtered = offers.where((o) {
        final asset = o.asset.trim().toUpperCase();
        return asset != 'USDC' || hasUsdc;
      }).toList();
      if (!mounted) return;
      setState(() {
        _paymentMethods = paymentMethods;
        _offers = filtered;
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

  Future<void> _openFilters() async {
    final qCtrl = TextEditingController(text: _filters.q ?? '');
    final fiatCtrl = TextEditingController(text: _filters.fiatCurrency ?? '');
    final amountCtrl = TextEditingController(text: _filters.amount ?? '');
    final minAmountCtrl = TextEditingController(text: _filters.minAmount ?? '');
    final maxAmountCtrl = TextEditingController(text: _filters.maxAmount ?? '');
    final sellerCtrl = TextEditingController(text: _filters.sellerId ?? '');
    final receiverCtrl = TextEditingController(
      text: _filters.receiverStellarAddress ?? '',
    );
    var nextFilters = _filters;

    final result = await showModalBottomSheet<_MarketOfferFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.of(context).surface,
      builder: (ctx) {
        final c = AppColor.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Widget gap() => const SizedBox(height: 12);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marketplace Filters',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Applies the `/offers` filters from the backend module spec.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    gap(),
                    _FilterTextField(
                      controller: qCtrl,
                      label: 'Search',
                      hint: 'Asset, fiat, seller name, email',
                      c: c,
                    ),
                    gap(),
                    _ChoiceRow<String>(
                      label: 'Asset',
                      value: nextFilters.asset,
                      options: const ['XLM', 'USDC'],
                      labelBuilder: (v) => v,
                      onChanged: (value) {
                        setModal(() {
                          nextFilters = nextFilters.copyWith(asset: value);
                        });
                      },
                      c: c,
                    ),
                    gap(),
                    _FilterTextField(
                      controller: fiatCtrl,
                      label: 'Fiat Currency',
                      hint: 'PHP, USD, SGD',
                      textCapitalization: TextCapitalization.characters,
                      c: c,
                    ),
                    gap(),
                    _FilterTextField(
                      controller: amountCtrl,
                      label: 'Amount',
                      hint: 'Match offers where min <= amount <= max',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      c: c,
                    ),
                    gap(),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterTextField(
                            controller: minAmountCtrl,
                            label: 'Min Amount',
                            hint: 'Range overlap min',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            c: c,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterTextField(
                            controller: maxAmountCtrl,
                            label: 'Max Amount',
                            hint: 'Range overlap max',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            c: c,
                          ),
                        ),
                      ],
                    ),
                    gap(),
                    _DropdownField<String?>(
                      label: 'Payment Method',
                      value: nextFilters.paymentMethodId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All payment methods'),
                        ),
                        ..._paymentMethods.map(
                          (method) => DropdownMenuItem<String?>(
                            value: method.id,
                            child: Text(method.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModal(() {
                          nextFilters =
                              nextFilters.copyWith(paymentMethodId: value);
                        });
                      },
                      c: c,
                    ),
                    gap(),
                    _DropdownField<OfferSortBy?>(
                      label: 'Sort By',
                      value: nextFilters.sortBy,
                      items: [
                        const DropdownMenuItem<OfferSortBy?>(
                          value: null,
                          child: Text('Backend default'),
                        ),
                        ...OfferSortBy.values.map(
                          (sort) => DropdownMenuItem<OfferSortBy?>(
                            value: sort,
                            child: Text(_sortLabel(sort)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModal(() {
                          nextFilters = nextFilters.copyWith(sortBy: value);
                        });
                      },
                      c: c,
                    ),
                    gap(),
                    _ChoiceRow<OfferSortOrder>(
                      label: 'Sort Order',
                      value: nextFilters.sortOrder,
                      options: OfferSortOrder.values,
                      labelBuilder: (v) => v.name.toUpperCase(),
                      onChanged: (value) {
                        setModal(() {
                          nextFilters = nextFilters.copyWith(sortOrder: value);
                        });
                      },
                      c: c,
                    ),
                    gap(),
                    _FilterTextField(
                      controller: sellerCtrl,
                      label: 'Seller ID',
                      hint: 'Optional exact seller filter',
                      c: c,
                    ),
                    gap(),
                    _FilterTextField(
                      controller: receiverCtrl,
                      label: 'Receiver Stellar Address',
                      hint: 'Optional exact receiver address',
                      c: c,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(
                                const _MarketOfferFilters(),
                              );
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(
                                nextFilters.copyWith(
                                  q: qCtrl.text.trim(),
                                  fiatCurrency: fiatCtrl.text.trim(),
                                  amount: amountCtrl.text.trim(),
                                  minAmount: minAmountCtrl.text.trim(),
                                  maxAmount: maxAmountCtrl.text.trim(),
                                  sellerId: sellerCtrl.text.trim(),
                                  receiverStellarAddress:
                                      receiverCtrl.text.trim(),
                                ).normalized(),
                              );
                            },
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    qCtrl.dispose();
    fiatCtrl.dispose();
    amountCtrl.dispose();
    minAmountCtrl.dispose();
    maxAmountCtrl.dispose();
    sellerCtrl.dispose();
    receiverCtrl.dispose();

    if (result == null || result == _filters) return;
    setState(() => _filters = result);
    _load();
  }

  String _sortLabel(OfferSortBy sort) {
    switch (sort) {
      case OfferSortBy.best:
        return 'Best';
      case OfferSortBy.newest:
        return 'Newest';
      case OfferSortBy.oldest:
        return 'Oldest';
      case OfferSortBy.successRate:
        return 'Success Rate';
      case OfferSortBy.minAmount:
        return 'Min Amount';
      case OfferSortBy.maxAmount:
        return 'Max Amount';
      case OfferSortBy.marginPercent:
        return 'Margin Percent';
    }
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
    final factor =
    isMerchantSell ? (1.0 + margin / 100.0) : (1.0 - margin / 100.0);
    return '${_formatFiat(fiatCode, live * factor)} $fiatCode';
  }

  double? _rawPriceForAsset(String assetCode) {
    final vm = switch (assetCode.trim().toUpperCase()) {
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
    final vm = switch (offer.asset.trim().toUpperCase()) {
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

  String _formatFiat(String fiatCode, double value, {int? decimalDigits}) =>
      NumberFormat.simpleCurrency(
          name: fiatCode, decimalDigits: decimalDigits)
          .format(value);

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
                selected: _selectedType,
                onChanged: _onTypeChanged,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FilterBar(
                c: c,
                activeCount: _filters.activeCount,
                summary: _filters.summary(_paymentMethods, _sortLabel),
                onTap: _openFilters,
              ),
            ),
            if (!_loading && _error == null && _offers.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OfferCountRow(c: c, count: _offers.length),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? _SkeletonList(c: c)
                  : _error != null
                  ? _ErrorState(c: c, error: _error!, onRetry: _load)
                  : RefreshIndicator(
                color: c.primary,
                onRefresh: _load,
                child: _offers.isEmpty
                    ? ListView(children: [
                  _EmptyState(c: c, type: _selectedType),
                ])
                    : FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 0, 20, 32),
                      itemCount: _offers.length,
                      itemBuilder: (_, i) {
                        final offer = _offers[i];
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: 12),
                          child: PublicOfferTile(
                            c: c,
                            offer: offer,
                            assetVm: _assetVm,
                            marketPrice:
                            _offerEffectivePrice(offer),
                            priceLoading:
                            _priceLoadingFor(offer),
                            enabled: _offerEnabled(offer),
                            shimmerAnim: _shimmerAnim,
                            onTap: () =>
                                _openOfferDetails(offer),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop) ...[
            _BackButton(c: c),
            const SizedBox(width: 12),
          ],
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
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          decoration:
          BoxDecoration(color: c.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: _T.label.copyWith(color: c.success),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFER COUNT ROW
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// MARKET PULSE STRIP
// ─────────────────────────────────────────────────────────────────────────────

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
        // Card
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
                    name: xlmVm.fiatCode, decimalDigits: 4)
                    .format(xlm)
                    : '--',
                changePercent:
                assetVm.findAsset('xlm')?.priceChangePercent24h,
              ),
              Container(
                  width: 1, height: 52, color: c.border.withValues(alpha: 0.5)),
              _PulseCell(
                c: c,
                logoUrl: assetVm.logoFor('usdc'),
                token: 'USDC',
                fiat: usdcVm.fiatCode,
                price: (usdc.isFinite && usdc > 0)
                    ? NumberFormat.simpleCurrency(
                    name: usdcVm.fiatCode, decimalDigits: 4)
                    .format(usdc)
                    : '--',
                changePercent:
                assetVm.findAsset('usdc')?.priceChangePercent24h,
              ),
            ],
          ),
        ),
        // Floating "Market Pulse" tab
        Positioned(
          top: -10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
            // Logo — rigid 30×30
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
            // Text — expands, never overflows
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

// ─────────────────────────────────────────────────────────────────────────────
// TYPE TOGGLE (BUY / SELL)
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
          color: active
              ? activeColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? c.onPrimary : c.textSecondary,
            ),
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
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_right_rounded,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.c,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final AppColor c;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.c,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: c.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    required this.c,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = option == value;
            return ChoiceChip(
              label: Text(labelBuilder(option)),
              selected: active,
              onSelected: (_) => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MarketOfferFilters {
  final String? q;
  final String? asset;
  final String? fiatCurrency;
  final String? paymentMethodId;
  final String? amount;
  final String? minAmount;
  final String? maxAmount;
  final String? sellerId;
  final String? receiverStellarAddress;
  final OfferSortBy? sortBy;
  final OfferSortOrder? sortOrder;

  const _MarketOfferFilters({
    this.q,
    this.asset,
    this.fiatCurrency,
    this.paymentMethodId,
    this.amount,
    this.minAmount,
    this.maxAmount,
    this.sellerId,
    this.receiverStellarAddress,
    this.sortBy,
    this.sortOrder,
  });

  _MarketOfferFilters copyWith({
    String? q,
    String? asset,
    String? fiatCurrency,
    String? paymentMethodId,
    String? amount,
    String? minAmount,
    String? maxAmount,
    String? sellerId,
    String? receiverStellarAddress,
    OfferSortBy? sortBy,
    OfferSortOrder? sortOrder,
  }) {
    return _MarketOfferFilters(
      q: q ?? this.q,
      asset: asset ?? this.asset,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      amount: amount ?? this.amount,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      sellerId: sellerId ?? this.sellerId,
      receiverStellarAddress:
          receiverStellarAddress ?? this.receiverStellarAddress,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  _MarketOfferFilters normalized() {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return _MarketOfferFilters(
      q: clean(q),
      asset: clean(asset),
      fiatCurrency: clean(fiatCurrency),
      paymentMethodId: clean(paymentMethodId),
      amount: clean(amount),
      minAmount: clean(minAmount),
      maxAmount: clean(maxAmount),
      sellerId: clean(sellerId),
      receiverStellarAddress: clean(receiverStellarAddress),
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  OffersListQuery toQuery({required OfferType type}) => OffersListQuery(
    type: type,
    q: q,
    asset: asset,
    fiatCurrency: fiatCurrency,
    paymentMethodId: paymentMethodId,
    amount: amount,
    minAmount: minAmount,
    maxAmount: maxAmount,
    sellerId: sellerId,
    receiverStellarAddress: receiverStellarAddress,
    sortBy: sortBy,
    sortOrder: sortOrder,
    page: '1',
    limit: '50',
  );

  int get activeCount {
    var count = 0;
    if ((q ?? '').isNotEmpty) count++;
    if ((asset ?? '').isNotEmpty) count++;
    if ((fiatCurrency ?? '').isNotEmpty) count++;
    if ((paymentMethodId ?? '').isNotEmpty) count++;
    if ((amount ?? '').isNotEmpty) count++;
    if ((minAmount ?? '').isNotEmpty || (maxAmount ?? '').isNotEmpty) count++;
    if ((sellerId ?? '').isNotEmpty) count++;
    if ((receiverStellarAddress ?? '').isNotEmpty) count++;
    if (sortBy != null) count++;
    if (sortOrder != null) count++;
    return count;
  }

  String summary(
    List<PaymentMethodModel> methods,
    String Function(OfferSortBy sort) sortLabel,
  ) {
    final parts = <String>[];
    if ((q ?? '').isNotEmpty) parts.add('Search');
    if ((asset ?? '').isNotEmpty) parts.add(asset!);
    if ((fiatCurrency ?? '').isNotEmpty) parts.add(fiatCurrency!.toUpperCase());
    if ((amount ?? '').isNotEmpty) parts.add('Amount $amount');
    if ((minAmount ?? '').isNotEmpty || (maxAmount ?? '').isNotEmpty) {
      parts.add('Range');
    }
    if ((paymentMethodId ?? '').isNotEmpty) {
      PaymentMethodModel? method;
      for (final item in methods) {
        if (item.id == paymentMethodId) {
          method = item;
          break;
        }
      }
      parts.add(method?.name ?? 'Payment method');
    }
    if (sortBy != null) parts.add('Sort ${sortLabel(sortBy!)}');
    if ((sellerId ?? '').isNotEmpty) parts.add('Seller');
    if ((receiverStellarAddress ?? '').isNotEmpty) parts.add('Receiver');
    return parts.isEmpty ? 'Search, amount, payment method, sort' : parts.join(' • ');
  }

  @override
  bool operator ==(Object other) {
    return other is _MarketOfferFilters &&
        other.q == q &&
        other.asset == asset &&
        other.fiatCurrency == fiatCurrency &&
        other.paymentMethodId == paymentMethodId &&
        other.amount == amount &&
        other.minAmount == minAmount &&
        other.maxAmount == maxAmount &&
        other.sellerId == sellerId &&
        other.receiverStellarAddress == receiverStellarAddress &&
        other.sortBy == sortBy &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    q,
    asset,
    fiatCurrency,
    paymentMethodId,
    amount,
    minAmount,
    maxAmount,
    sellerId,
    receiverStellarAddress,
    sortBy,
    sortOrder,
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
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
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
            child: Icon(Icons.storefront_outlined,
                color: c.textSecondary, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${type == OfferType.sell ? 'buy' : 'sell'} offers right now',
            textAlign: TextAlign.center,
            style: _T.emptyTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh the marketplace.',
            textAlign: TextAlign.center,
            style: _T.emptyBody.copyWith(color: c.textSecondary),
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
              color: c.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: c.error.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.cloud_off_rounded,
                color: c.error, size: 22),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
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
  late final Animation<double> _anim =
  CurvedAnimation(parent: _ctrl, curve: Curves.linear);

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
        // Merchant type skeleton
        _box(72, 20, 5),
        const SizedBox(height: 10),
        // Merchant row
        Row(children: [
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
                ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        // Asset row
        Row(children: [
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
                ]),
          ),
          _box(76, 36, 10),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        _box(140, 11, 3),
        const SizedBox(height: 10),
        // Action row
        Row(children: [
          Expanded(child: _box(double.infinity, 40, 10)),
          const SizedBox(width: 8),
          _box(100, 40, 10),
        ]),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER BOX  (local — mirrors the one in public_offer_tile.dart)
// ─────────────────────────────────────────────────────────────────────────────

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
                return Stack(children: [
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
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
