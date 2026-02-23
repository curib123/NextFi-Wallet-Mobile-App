import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/showFiatPickerBottomSheet.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/wallet/models/wallet_models.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE OFFERS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({super.key});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen>
    with TickerProviderStateMixin {
  final _offersCore = OffersCoreService.I;
  final _paymentMethodsCore = PaymentMethodAndAccountsCoreService.I;
  final _walletCore = WalletCoreService.I;

  bool _loading = true;
  bool _submitting = false;
  List<OfferModel> _offers = const [];
  List<PaymentMethodModel> _paymentMethods = const [];
  List<WalletAddress> _wallets = const [];
  String? _error;

  final _marginCtrl = TextEditingController(text: '0');
  final _minCtrl = TextEditingController(text: '0');
  final _maxCtrl = TextEditingController(text: '0');
  final _totalQtyCtrl = TextEditingController();
  final _availableQtyCtrl = TextEditingController();
  final _paymentWindowCtrl = TextEditingController(text: '15');
  final _autoReplyCtrl = TextEditingController();
  OfferType _type = OfferType.sell;
  PaymentMethodModel? _selectedPaymentMethod;
  WalletAddress? _selectedReceiverWallet;
  String? _selectedAssetSymbol;
  bool _isVisible = true;

  late final AnimationController _pageEnterCtrl;
  late final AnimationController _heroCtrl;
  late final Animation<double> _pageAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pageAnim = CurvedAnimation(
      parent: _pageEnterCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageEnterCtrl,
      curve: Curves.easeOutCubic,
    ));
    _load();
  }

  @override
  void dispose() {
    _marginCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _totalQtyCtrl.dispose();
    _availableQtyCtrl.dispose();
    _paymentWindowCtrl.dispose();
    _autoReplyCtrl.dispose();
    _pageEnterCtrl.dispose();
    _heroCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final methods = await _paymentMethodsCore.listPaymentMethods(activeOnly: true);
      final wallets = await _walletCore.list();
      final offers = await _offersCore.listMine(
        query: const OffersListQuery(page: '1', limit: '50'),
      );
      WalletAddress? selectedWallet;
      for (final w in wallets) {
        if (w.isActive) {
          selectedWallet = w;
          break;
        }
      }
      selectedWallet ??= wallets.isEmpty ? null : wallets.first;
      if (!mounted) return;
      setState(() {
        _paymentMethods = methods;
        _wallets = wallets;
        _selectedPaymentMethod = methods.isEmpty ? null : methods.first;
        _selectedReceiverWallet = selectedWallet;
        _offers = offers;
        _loading = false;
      });
      _pageEnterCtrl.forward(from: 0);
      _heroCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createOffer() async {
    final paymentMethod = _selectedPaymentMethod;
    if (paymentMethod == null) {
      _showSnack('Select a payment method first.', isError: true);
      return;
    }
    final assets = context.read<AssetVM>().assets;
    if (assets.isEmpty) {
      _showSnack('No assets available.', isError: true);
      return;
    }
    final fallbackAsset = assets.first.symbol.toUpperCase();
    final asset = (_selectedAssetSymbol ?? fallbackAsset).trim().toUpperCase();
    final fiat = context.read<CurrencyVM>().fiat.trim().toUpperCase();
    final margin = double.tryParse(_marginCtrl.text.trim());
    final minAmount = double.tryParse(_minCtrl.text.trim());
    final maxAmount = double.tryParse(_maxCtrl.text.trim());
    final totalQty = double.tryParse(_totalQtyCtrl.text.trim());
    final availableQty = double.tryParse(_availableQtyCtrl.text.trim());
    final paymentWindowMinutes = int.tryParse(_paymentWindowCtrl.text.trim());
    final receiverStellarAddress = _selectedReceiverWallet?.publicAddress.trim() ?? '';

    if (asset.isEmpty || fiat.isEmpty) {
      _showSnack('Asset and fiat currency are required.', isError: true);
      return;
    }
    if (margin == null || minAmount == null || maxAmount == null) {
      _showSnack('Enter valid numbers for margin, min and max.', isError: true);
      return;
    }
    if (maxAmount < minAmount) {
      _showSnack('Max must be ≥ min amount.', isError: true);
      return;
    }
    if (_totalQtyCtrl.text.trim().isNotEmpty && totalQty == null) {
      _showSnack('Enter a valid total quantity.', isError: true);
      return;
    }
    if (_availableQtyCtrl.text.trim().isNotEmpty && availableQty == null) {
      _showSnack('Enter a valid available quantity.', isError: true);
      return;
    }
    if (totalQty != null && availableQty != null && availableQty > totalQty) {
      _showSnack('Available quantity cannot exceed total quantity.', isError: true);
      return;
    }
    if (_paymentWindowCtrl.text.trim().isNotEmpty && paymentWindowMinutes == null) {
      _showSnack('Enter a valid payment window (minutes).', isError: true);
      return;
    }
    // Wallet service provides persisted addresses, but keep safe guard.
    if (receiverStellarAddress.isNotEmpty &&
        !RegExp(r'^G[A-Z2-7]{55}$').hasMatch(receiverStellarAddress)) {
      _showSnack('Selected wallet has invalid Stellar address format.', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await _offersCore.create(
        CreateOfferRequest(
          type: _type,
          asset: asset,
          fiatCurrency: fiat,
          receiverStellarAddress:
              receiverStellarAddress.isEmpty ? null : receiverStellarAddress,
          marginPercent: margin,
          minAmount: minAmount,
          maxAmount: maxAmount,
          totalQty: totalQty,
          availableQty: availableQty,
          paymentWindowMinutes: paymentWindowMinutes,
          autoReply: _autoReplyCtrl.text.trim().isEmpty
              ? null
              : _autoReplyCtrl.text.trim(),
          isVisible: _isVisible,
          paymentMethodIds: [paymentMethod.id],
        ),
      );
      _marginCtrl.text = '0';
      _minCtrl.text = '0';
      _maxCtrl.text = '0';
      _totalQtyCtrl.clear();
      _availableQtyCtrl.clear();
      _paymentWindowCtrl.text = '15';
      _autoReplyCtrl.clear();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _showSnack('Offer created successfully!', isError: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to create offer: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pauseOrResume(OfferModel offer) async {
    HapticFeedback.selectionClick();
    try {
      if (offer.status == OfferStatus.active) {
        await _offersCore.pause(offer.id);
      } else if (offer.status == OfferStatus.paused) {
        await _offersCore.resume(offer.id);
      }
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to update offer: $e', isError: true);
    }
  }

  Future<void> _cancel(OfferModel offer) async {
    showAppAlert(
      context,
      type: AppAlertType.warning,
      title: 'Cancel Offer?',
      subtitle:
          'This offer will be permanently cancelled and removed from the marketplace.',
      primaryText: 'Cancel Offer',
      barrierDismissible: true,
      onPrimary: () => _performCancelOffer(offer),
    );
  }

  Future<void> _performCancelOffer(OfferModel offer) async {
    HapticFeedback.mediumImpact();
    try {
      await _offersCore.cancel(offer.id);
      if (!mounted) return;
      _showSnack('Offer cancelled.', isError: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to cancel offer: $e', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    showFloatingSnackBar(
      context,
      message: message,
      type: isError ? SnackBarType.error : SnackBarType.success,
      position: SnackBarPosition.top,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final assets = context.select<AssetVM, List<AssetModel>>((vm) => vm.assets);
    final resolvedSelectedAsset = _selectedAssetSymbol != null &&
        assets.any((a) => a.symbol.toUpperCase() == _selectedAssetSymbol)
        ? _selectedAssetSymbol
        : (assets.isEmpty ? null : assets.first.symbol.toUpperCase());

    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: _loading
          ? const PageLoader(label: 'Loading offers...')
          : _error != null
          ? _ErrorState(c: c, error: _error!, onRetry: _load)
          : FadeTransition(
        opacity: _pageAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.primary,
            backgroundColor: c.surface,
            displacement: 60,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _OffersHeroCard(
                        c: c,
                        offers: _offers,
                        accountCount: _paymentMethods.length,
                        animCtrl: _heroCtrl,
                      ),
                      if (_paymentMethods.isEmpty) ...[
                        const SizedBox(height: 12),
                        _NoticeBanner(
                          c: c,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No Active Payment Method',
                          body:
                          'No active payment method found. Enable at least one payment method before posting offers.',
                          accent: c.warning,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _SectionLabel(
                        c: c,
                        label: 'Create Offer',
                        icon: Icons.add_circle_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _CreateOfferCard(
                        c: c,
                        assets: assets,
                        selectedAssetSymbol: resolvedSelectedAsset,
                        fiatCode: context.select<CurrencyVM, String>(
                              (vm) => vm.fiat.toUpperCase(),
                        ),
                        marginCtrl: _marginCtrl,
                        minCtrl: _minCtrl,
                        maxCtrl: _maxCtrl,
                        totalQtyCtrl: _totalQtyCtrl,
                        availableQtyCtrl: _availableQtyCtrl,
                        paymentWindowCtrl: _paymentWindowCtrl,
                        wallets: _wallets,
                        selectedReceiverWallet: _selectedReceiverWallet,
                        autoReplyCtrl: _autoReplyCtrl,
                        type: _type,
                        methods: _paymentMethods,
                        selectedMethod: _selectedPaymentMethod,
                        isVisible: _isVisible,
                        submitting: _submitting,
                        onTypeChanged: (v) => setState(() => _type = v),
                        onAssetChanged: (v) =>
                            setState(() => _selectedAssetSymbol = v),
                        onMethodChanged: (v) =>
                            setState(() => _selectedPaymentMethod = v),
                        onReceiverWalletChanged: (v) =>
                            setState(() => _selectedReceiverWallet = v),
                        onVisibleChanged: (v) =>
                            setState(() => _isVisible = v),
                        onSubmit: _createOffer,
                      ),
                      const SizedBox(height: 28),
                      _SectionLabel(
                        c: c,
                        label: 'My Offers',
                        icon: Icons.list_alt_rounded,
                        badge: _offers.isEmpty ? null : '${_offers.length}',
                      ),
                      const SizedBox(height: 12),
                      if (_offers.isEmpty)
                        _EmptyOffersCard(c: c)
                      else
                        ..._offers.asMap().entries.map(
                              (entry) => _AnimatedOfferTile(
                            index: entry.key,
                            c: c,
                            offer: entry.value,
                            onPauseOrResume: () =>
                                _pauseOrResume(entry.value),
                            onCancel: () => _cancel(entry.value),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: c.border.withOpacity(0.15),
      centerTitle: false,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Offers',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _AnimatedRefreshButton(c: c, onTap: _load),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED REFRESH BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedRefreshButton extends StatefulWidget {
  const _AnimatedRefreshButton({required this.c, required this.onTap});
  final AppColor c;
  final VoidCallback onTap;

  @override
  State<_AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<_AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return GestureDetector(
      onTap: () {
        _ctrl.forward(from: 0);
        widget.onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withOpacity(0.3)),
        ),
        child: RotationTransition(
          turns: _ctrl,
          child: Icon(
            Icons.refresh_rounded,
            color: c.textSecondary,
            size: 19,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OffersHeroCard extends StatelessWidget {
  const _OffersHeroCard({
    required this.c,
    required this.offers,
    required this.accountCount,
    required this.animCtrl,
  });

  final AppColor c;
  final List<OfferModel> offers;
  final int accountCount;
  final AnimationController animCtrl;

  @override
  Widget build(BuildContext context) {
    final activeCount = offers.where((o) => o.status == OfferStatus.active).length;
    final pausedCount = offers.where((o) => o.status == OfferStatus.paused).length;
    final total = offers.length;
    final progress = total == 0 ? 0.0 : (activeCount / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: c.primary.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MERCHANT DASHBOARD',
                    style: TextStyle(
                      color: c.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Spacer(),
                _StatPill(
                  c: c,
                  value: '$total',
                  label: 'total',
                  color: c.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your Marketplace\nOffers',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatChip(
                  c: c,
                  value: '$activeCount',
                  label: 'Active',
                  color: c.success,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  c: c,
                  value: '$pausedCount',
                  label: 'Paused',
                  color: c.warning,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  c: c,
                  value: '$accountCount',
                  label: 'Accounts',
                  color: c.primary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Activity',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            total == 0
                                ? '–'
                                : '${(progress * 100).toStringAsFixed(0)}% active',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedBuilder(
                        animation: animCtrl,
                        builder: (_, __) {
                          final animated = Curves.easeOutCubic
                              .transform(animCtrl.value);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress * animated,
                              minHeight: 7,
                              backgroundColor: c.border.withOpacity(0.25),
                              valueColor:
                              AlwaysStoppedAnimation<Color>(c.primary),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.c,
    required this.value,
    required this.label,
    required this.color,
  });

  final AppColor c;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.c,
    required this.value,
    required this.label,
    required this.color,
  });

  final AppColor c;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.c,
    required this.label,
    required this.icon,
    this.badge,
  });

  final AppColor c;
  final String label;
  final IconData icon;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c.primary, size: 15),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                color: c.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE OFFER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CreateOfferCard extends StatelessWidget {
  const _CreateOfferCard({
    required this.c,
    required this.assets,
    required this.selectedAssetSymbol,
    required this.fiatCode,
    required this.marginCtrl,
    required this.minCtrl,
    required this.maxCtrl,
    required this.totalQtyCtrl,
    required this.availableQtyCtrl,
    required this.paymentWindowCtrl,
    required this.wallets,
    required this.selectedReceiverWallet,
    required this.autoReplyCtrl,
    required this.type,
    required this.methods,
    required this.selectedMethod,
    required this.isVisible,
    required this.submitting,
    required this.onTypeChanged,
    required this.onAssetChanged,
    required this.onMethodChanged,
    required this.onReceiverWalletChanged,
    required this.onVisibleChanged,
    required this.onSubmit,
  });

  final AppColor c;
  final List<AssetModel> assets;
  final String? selectedAssetSymbol;
  final String fiatCode;
  final TextEditingController marginCtrl;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final TextEditingController totalQtyCtrl;
  final TextEditingController availableQtyCtrl;
  final TextEditingController paymentWindowCtrl;
  final List<WalletAddress> wallets;
  final WalletAddress? selectedReceiverWallet;
  final TextEditingController autoReplyCtrl;
  final OfferType type;
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selectedMethod;
  final bool isVisible;
  final bool submitting;
  final ValueChanged<OfferType> onTypeChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<PaymentMethodModel?> onMethodChanged;
  final ValueChanged<WalletAddress?> onReceiverWalletChanged;
  final ValueChanged<bool> onVisibleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TypeSelectorBar(
              c: c,
              selected: type,
              onChanged: onTypeChanged,
            ),
          ),

          const _CardDivider(),

          // ── Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(c: c, label: 'Asset & Currency'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StyledDropdown<String>(
                        c: c,
                        value: selectedAssetSymbol,
                        hint: 'Asset',
                        icon: Icons.currency_bitcoin_rounded,
                        items: assets
                            .map((a) => DropdownMenuItem(
                          value: a.symbol.toUpperCase(),
                          child: Text(a.symbol.toUpperCase()),
                        ))
                            .toList(),
                        onChanged: onAssetChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FiatSelector(c: c, fiatCode: fiatCode),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Margin'),
                const SizedBox(height: 8),
                _PercentField(c: c, controller: marginCtrl),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Trade Limits'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        c: c,
                        controller: minCtrl,
                        label: 'Min',
                        prefixIcon: Icons.arrow_downward_rounded,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        c: c,
                        controller: maxCtrl,
                        label: 'Max',
                        prefixIcon: Icons.arrow_upward_rounded,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Quantity & Window (optional)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        c: c,
                        controller: totalQtyCtrl,
                        label: 'Total Qty',
                        prefixIcon: Icons.inventory_2_outlined,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Field(
                        c: c,
                        controller: availableQtyCtrl,
                        label: 'Available Qty',
                        prefixIcon: Icons.dataset_outlined,
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Field(
                  c: c,
                  controller: paymentWindowCtrl,
                  label: 'Payment Window (minutes)',
                  prefixIcon: Icons.timer_outlined,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Receiver Stellar Address (optional)'),
                const SizedBox(height: 8),
                _StyledDropdown<WalletAddress>(
                  c: c,
                  value: selectedReceiverWallet,
                  hint: wallets.isEmpty ? 'No wallet available' : 'Select receiver wallet',
                  icon: Icons.alternate_email_rounded,
                  items: wallets
                      .map(
                        (w) => DropdownMenuItem<WalletAddress>(
                          value: w,
                          child: Text(
                            _walletLabel(w),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onReceiverWalletChanged,
                ),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Auto Reply Message'),
                const SizedBox(height: 8),
                _Field(
                  c: c,
                  controller: autoReplyCtrl,
                  label: 'Optional greeting to buyers',
                  prefixIcon: Icons.chat_bubble_outline_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _FieldLabel(c: c, label: 'Payment Method'),
                const SizedBox(height: 8),
                _StyledDropdown<PaymentMethodModel>(
                  c: c,
                  value: selectedMethod,
                  hint: 'Select method',
                  icon: Icons.account_balance_rounded,
                  items: methods
                      .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      '${m.name} (${m.code})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
                      .toList(),
                  onChanged: onMethodChanged,
                ),
              ],
            ),
          ),

          const _CardDivider(),

          // ── Visibility toggle + submit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                _VisibilityToggle(
                  c: c,
                  isVisible: isVisible,
                  onChanged: onVisibleChanged,
                ),
                const SizedBox(height: 14),
                _SubmitButton(
                  c: c,
                  submitting: submitting,
                  type: type,
                  onSubmit: onSubmit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _walletLabel(WalletAddress wallet) {
    final label = (wallet.label ?? '').trim();
    final shortAddress = wallet.publicAddress.length > 14
        ? '${wallet.publicAddress.substring(0, 6)}...${wallet.publicAddress.substring(wallet.publicAddress.length - 6)}'
        : wallet.publicAddress;
    final prefix = wallet.isActive ? 'Active' : 'Wallet';
    if (label.isNotEmpty) return '$prefix · $label · $shortAddress';
    return '$prefix · $shortAddress';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE SELECTOR BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TypeSelectorBar extends StatelessWidget {
  const _TypeSelectorBar({
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
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _TypeChip(
            c: c,
            selected: selected == OfferType.buy,
            label: 'BUY',
            icon: Icons.south_west_rounded,
            activeColor: c.success,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(OfferType.buy);
            },
          ),
          const SizedBox(width: 4),
          _TypeChip(
            c: c,
            selected: selected == OfferType.sell,
            label: 'SELL',
            icon: Icons.north_east_rounded,
            activeColor: c.primary,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(OfferType.sell);
            },
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.c,
    required this.selected,
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.onTap,
  });

  final AppColor c;
  final bool selected;
  final String label;
  final IconData icon;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : c.textSecondary,
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: selected ? Colors.white : c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.c, required this.label});
  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.c,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.isNumber = false,
    this.maxLines = 1,
  });

  final AppColor c;
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool isNumber;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: c.textSecondary.withOpacity(0.6),
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 17, color: c.textSecondary.withOpacity(0.7))
            : null,
        filled: true,
        fillColor: c.background.withOpacity(0.6),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({required this.c, required this.controller});
  final AppColor c;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(
          color: c.textSecondary.withOpacity(0.4),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        suffixText: '%',
        suffixStyle: TextStyle(
          color: c.primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: c.background.withOpacity(0.6),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.c,
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final AppColor c;
  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: c.textSecondary.withOpacity(0.7), size: 20),
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: c.textSecondary.withOpacity(0.6),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, size: 17, color: c.textSecondary.withOpacity(0.7)),
        filled: true,
        fillColor: c.background.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.primary, width: 1.6),
        ),
      ),
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      dropdownColor: c.surface,
    );
  }
}

class _FiatSelector extends StatelessWidget {
  const _FiatSelector({required this.c, required this.fiatCode});
  final AppColor c;
  final String fiatCode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showFiatPickerBottomSheet(context);
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.background.withOpacity(0.6),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.border.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.paid_outlined,
                size: 17, color: c.textSecondary.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fiatCode,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: c.textSecondary.withOpacity(0.7), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISIBILITY TOGGLE
// ─────────────────────────────────────────────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.c,
    required this.isVisible,
    required this.onChanged,
  });

  final AppColor c;
  final bool isVisible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: isVisible
            ? c.primary.withOpacity(0.06)
            : c.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVisible
              ? c.primary.withOpacity(0.2)
              : c.border.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              key: ValueKey(isVisible),
              size: 18,
              color: isVisible ? c.primary : c.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketplace visibility',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isVisible
                      ? 'Visible to buyers'
                      : 'Hidden from marketplace',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isVisible,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: c.primary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.c,
    required this.submitting,
    required this.type,
    required this.onSubmit,
  });

  final AppColor c;
  final bool submitting;
  final OfferType type;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isBuy = type == OfferType.buy;
    final color = isBuy ? c.success : c.primary;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: submitting
              ? null
              : [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: submitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: submitting
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Creating offer...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBuy
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isBuy ? 'Post Buy Offer' : 'Post Sell Offer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFER TILE (with animation)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedOfferTile extends StatefulWidget {
  const _AnimatedOfferTile({
    required this.index,
    required this.c,
    required this.offer,
    required this.onPauseOrResume,
    required this.onCancel,
  });

  final int index;
  final AppColor c;
  final OfferModel offer;
  final VoidCallback onPauseOrResume;
  final VoidCallback onCancel;

  @override
  State<_AnimatedOfferTile> createState() => _AnimatedOfferTileState();
}

class _AnimatedOfferTileState extends State<_AnimatedOfferTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 60),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OfferTile(
            c: widget.c,
            offer: widget.offer,
            onPauseOrResume: widget.onPauseOrResume,
            onCancel: widget.onCancel,
          ),
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.c,
    required this.offer,
    required this.onPauseOrResume,
    required this.onCancel,
  });

  final AppColor c;
  final OfferModel offer;
  final VoidCallback onPauseOrResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = offer.status;
    final isBuy = offer.type == OfferType.buy;
    final canPauseResume =
        status == OfferStatus.active || status == OfferStatus.paused;
    final accent = _statusAccent(c, status);
    final typeColor = isBuy ? c.success : c.primary;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBuy
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
                      Text(
                        '${isBuy ? 'BUY' : 'SELL'} ${offer.asset}/${offer.fiatCurrency}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Margin ${offer.marginPercent ?? 0}%',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(c: c, status: status, accent: accent),
              ],
            ),
          ),

          // ── Metrics Row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.background.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _MetricItem(
                  c: c,
                  label: 'Min',
                  value: _fmt(offer.minAmount),
                  icon: Icons.arrow_downward_rounded,
                ),
                _VerticalDivider(c: c),
                _MetricItem(
                  c: c,
                  label: 'Max',
                  value: _fmt(offer.maxAmount),
                  icon: Icons.arrow_upward_rounded,
                ),
                _VerticalDivider(c: c),
                _MetricItem(
                  c: c,
                  label: 'Margin',
                  value: '${offer.marginPercent ?? 0}%',
                  icon: Icons.percent_rounded,
                ),
              ],
            ),
          ),

          // ── Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                if (canPauseResume) ...[
                  Expanded(
                    child: _ActionButton(
                      c: c,
                      label: status == OfferStatus.active ? 'Pause' : 'Resume',
                      icon: status == OfferStatus.active
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: c.textPrimary,
                      borderColor: c.border.withOpacity(0.3),
                      onTap: onPauseOrResume,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _ActionButton(
                  c: c,
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  color: c.error,
                  borderColor: c.error.withOpacity(0.25),
                  onTap: onCancel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '–';
    if (val is double) {
      return val == val.truncate()
          ? val.toInt().toString()
          : val.toStringAsFixed(2);
    }
    return val.toString();
  }

  Color _statusAccent(AppColor c, OfferStatus? status) {
    switch (status) {
      case OfferStatus.active:
        return c.success;
      case OfferStatus.paused:
        return c.warning;
      case OfferStatus.completed:
        return c.primary;
      case OfferStatus.cancelled:
        return c.error;
      default:
        return c.textSecondary;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.c,
    required this.status,
    required this.accent,
  });

  final AppColor c;
  final OfferStatus? status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isActive = status == OfferStatus.active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isActive)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Text(
            status?.name.toUpperCase() ?? 'UNKNOWN',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.c,
    required this.label,
    required this.value,
    required this.icon,
  });

  final AppColor c;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: c.border.withOpacity(0.3),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.c,
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  final AppColor c;
  final String label;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyOffersCard extends StatelessWidget {
  const _EmptyOffersCard({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.storefront_outlined, color: c.primary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'No offers yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create your first offer above to\nstart trading on the marketplace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTICE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.c,
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final AppColor c;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DIVIDER
// ─────────────────────────────────────────────────────────────────────────────

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      height: 1,
      color: c.border.withOpacity(0.15),
    );
  }
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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.cloud_off_rounded, color: c.error, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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