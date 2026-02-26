import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
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
import 'package:next_fi/services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/services/wallet/models/wallet_models.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE OFFERS SCREEN
// Design: Stripe-grade fintech — precise rhythm, confident type, clean density
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
  bool _syncingAvailableQty = false;
  Timer? _availableQtyTimer;
  double? _liveAvailableQty;
  List<OfferModel> _offers = const [];
  List<PaymentMethodModel> _paymentMethods = const [];
  List<WalletAddress> _wallets = const [];
  String? _error;

  final _marginCtrl        = TextEditingController(text: '0');
  final _minCtrl           = TextEditingController(text: '0');
  final _maxCtrl           = TextEditingController(text: '0');
  final _totalQtyCtrl      = TextEditingController();
  final _availableQtyCtrl  = TextEditingController();
  final _paymentWindowCtrl = TextEditingController(text: '15');
  final _autoReplyCtrl     = TextEditingController();

  OfferType _type = OfferType.sell;
  PaymentMethodModel? _selectedPaymentMethod;
  WalletAddress? _selectedReceiverWallet;
  String? _selectedAssetSymbol;
  bool _isVisible = true;

  late final AnimationController _pageEnterCtrl;
  late final AnimationController _heroCtrl;
  late final Animation<double> _pageAnim;
  late final Animation<Offset> _slideAnim;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _pageEnterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pageAnim = CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageEnterCtrl, curve: Curves.easeOutCubic));
    _load();
    _availableQtyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncAvailableQty(silent: true);
    });
  }

  @override
  void dispose() {
    _availableQtyTimer?.cancel();
    _marginCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _totalQtyCtrl.dispose();
    _availableQtyCtrl.dispose();
    _paymentWindowCtrl.dispose();
    _autoReplyCtrl.dispose();
    _pageEnterCtrl.dispose();
    _heroCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final methods = await _paymentMethodsCore.listPaymentMethods(activeOnly: true);
      final wallets = await _walletCore.list();
      final offers  = await _offersCore.listMine(
        query: const OffersListQuery(page: '1', limit: '50'),
      );
      WalletAddress? selected;
      for (final w in wallets) { if (w.isActive) { selected = w; break; } }
      selected ??= wallets.isEmpty ? null : wallets.first;
      if (!mounted) return;
      setState(() {
        _paymentMethods          = methods;
        _wallets                 = wallets;
        _selectedPaymentMethod   = methods.isEmpty ? null : methods.first;
        _selectedReceiverWallet  = selected;
        _offers                  = offers;
        _loading                 = false;
      });
      _syncAvailableQty(silent: true);
      _pageEnterCtrl.forward(from: 0);
      _heroCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _createOffer() async {
    final paymentMethod = _selectedPaymentMethod;
    if (paymentMethod == null) { _snack('Select a payment method first.', error: true); return; }
    final assets = context.read<AssetVM>().assets;
    if (assets.isEmpty) { _snack('No assets available.', error: true); return; }
    final asset   = (_selectedAssetSymbol ?? assets.first.symbol.toUpperCase()).trim().toUpperCase();
    final fiat    = context.read<CurrencyVM>().fiat.trim().toUpperCase();
    final margin  = double.tryParse(_marginCtrl.text.trim());
    final minAmt  = double.tryParse(_minCtrl.text.trim());
    final maxAmt  = double.tryParse(_maxCtrl.text.trim());
    final totalQ  = double.tryParse(_totalQtyCtrl.text.trim());
    final availQInput = double.tryParse(_availableQtyCtrl.text.trim());
    final window  = int.tryParse(_paymentWindowCtrl.text.trim());
    final addr    = _selectedReceiverWallet?.publicAddress.trim() ?? '';

    if (asset.isEmpty || fiat.isEmpty)    { _snack('Asset and fiat are required.',          error: true); return; }
    if (margin == null || minAmt == null || maxAmt == null) { _snack('Enter valid numbers for margin, min and max.', error: true); return; }
    if (maxAmt < minAmt)                  { _snack('Max must be ≥ min amount.',             error: true); return; }
    if (_totalQtyCtrl.text.trim().isNotEmpty && totalQ == null) { _snack('Enter a valid total quantity.',  error: true); return; }
    if (_availableQtyCtrl.text.trim().isNotEmpty && availQInput == null) { _snack('Enter a valid available quantity.', error: true); return; }
    if (totalQ != null && availQInput != null && availQInput > totalQ) { _snack('Available qty cannot exceed total qty.', error: true); return; }
    if (_paymentWindowCtrl.text.trim().isNotEmpty && window == null) { _snack('Enter a valid payment window (minutes).', error: true); return; }
    if (addr.isNotEmpty && !RegExp(r'^G[A-Z2-7]{55}$').hasMatch(addr)) { _snack('Invalid Stellar address format.', error: true); return; }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final liveAvail = await _syncAvailableQtyForSubmit(asset);
      final effectiveAvailableQty = totalQ == null
          ? liveAvail
          : math.min(totalQ, liveAvail);

      await _offersCore.create(CreateOfferRequest(
        type: _type,
        asset: asset,
        fiatCurrency: fiat,
        receiverStellarAddress: addr.isEmpty ? null : addr,
        marginPercent: margin,
        minAmount: minAmt,
        maxAmount: maxAmt,
        totalQty: totalQ,
        availableQty: effectiveAvailableQty,
        paymentWindowMinutes: window,
        autoReply: _autoReplyCtrl.text.trim().isEmpty ? null : _autoReplyCtrl.text.trim(),
        isVisible: _isVisible,
        paymentMethodIds: [paymentMethod.id],
      ));
      _marginCtrl.text = '0';
      _minCtrl.text    = '0';
      _maxCtrl.text    = '0';
      _totalQtyCtrl.clear();
      _availableQtyCtrl.clear();
      _paymentWindowCtrl.text = '15';
      _autoReplyCtrl.clear();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _snack('Offer created successfully!', error: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to create offer: $e', error: true);
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
      _snack('Failed to update offer: $e', error: true);
    }
  }

  Future<void> _cancel(OfferModel offer) async {
    showAppAlert(context,
      type: AppAlertType.warning,
      title: 'Cancel Offer?',
      subtitle: 'This offer will be permanently cancelled and removed from the marketplace.',
      primaryText: 'Cancel Offer',
      barrierDismissible: true,
      onPrimary: () => _performCancel(offer),
    );
  }

  Future<void> _performCancel(OfferModel offer) async {
    HapticFeedback.mediumImpact();
    try {
      await _offersCore.cancel(offer.id);
      if (!mounted) return;
      _snack('Offer cancelled.', error: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to cancel offer: $e', error: true);
    }
  }

  void _snack(String message, {required bool error}) => showFloatingSnackBar(
    context,
    message: message,
    type: error ? SnackBarType.error : SnackBarType.success,
    position: SnackBarPosition.top,
  );

  WalletAddress? _activeWallet() {
    for (final w in _wallets) {
      if (w.isActive && w.publicAddress.trim().isNotEmpty) return w;
    }
    for (final w in _wallets) {
      if (w.publicAddress.trim().isNotEmpty) return w;
    }
    return null;
  }

  String _formatQty(double value) {
    final fixed = value.toStringAsFixed(7);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<double> _fetchLiveAvailableQty(String assetUpper) async {
    final wallet = _activeWallet();
    final accountId = wallet?.publicAddress.trim() ?? '';
    if (accountId.isEmpty) return 0.0;

    final stellar = context.read<StellarWalletServices>();
    if (assetUpper == 'XLM') {
      return await stellar.getXlmBalance(accountId);
    }
    if (assetUpper == 'USDC') {
      return await stellar.getUsdcBalance(accountId);
    }

    final balances = await stellar.getAllBalances(accountId);
    for (final b in balances) {
      final code = (b.assetCode ?? '').trim().toUpperCase();
      if (code != assetUpper) continue;
      final bal = double.tryParse(b.balance) ?? 0.0;
      final liabilities = double.tryParse(b.sellingLiabilities ?? '0') ?? 0.0;
      final available = bal - liabilities;
      return available > 0 ? available : 0.0;
    }
    return 0.0;
  }

  Future<void> _syncAvailableQty({bool silent = false}) async {
    if (_loading || _submitting) return;
    if (_syncingAvailableQty) return;
    final assets = context.read<AssetVM>().assets;
    final selected = (_selectedAssetSymbol ??
            (assets.isNotEmpty ? assets.first.symbol.toUpperCase() : ''))
        .trim()
        .toUpperCase();
    if (selected.isEmpty) return;

    if (silent) {
      _syncingAvailableQty = true;
    } else {
      setState(() => _syncingAvailableQty = true);
    }
    try {
      final qty = await _fetchLiveAvailableQty(selected);
      if (!mounted) return;
      setState(() {
        _liveAvailableQty = qty;
        _availableQtyCtrl.text = _formatQty(qty);
      });
    } catch (e) {
      if (!silent && mounted) {
        _snack('Failed to sync live balance for available qty.', error: true);
      }
    } finally {
      if (mounted) {
        if (silent) {
          _syncingAvailableQty = false;
        } else {
          setState(() => _syncingAvailableQty = false);
        }
      }
    }
  }

  Future<double> _syncAvailableQtyForSubmit(String assetUpper) async {
    try {
      final qty = await _fetchLiveAvailableQty(assetUpper.toUpperCase());
      if (mounted) {
        setState(() {
          _liveAvailableQty = qty;
          _availableQtyCtrl.text = _formatQty(qty);
        });
      }
      return qty;
    } catch (_) {
      final fallback = _liveAvailableQty ?? 0.0;
      if (mounted) {
        _availableQtyCtrl.text = _formatQty(fallback);
      }
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = AppColor.of(context);
    final assets = context.select<AssetVM, List<AssetModel>>((vm) => vm.assets);
    final fiat   = context.select<CurrencyVM, String>((vm) => vm.fiat.toUpperCase());
    final resolvedAsset = _selectedAssetSymbol != null &&
        assets.any((a) => a.symbol.toUpperCase() == _selectedAssetSymbol)
        ? _selectedAssetSymbol
        : (assets.isEmpty ? null : assets.first.symbol.toUpperCase());

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: _loading
            ? const PageLoader(label: 'Loading offers…')
            : _error != null
            ? _ErrorState(c: c, error: _error!, onRetry: _load)
            : FadeTransition(
          opacity: _pageAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header
                _ScreenHeader(c: c, onRefresh: _load),

                // ── Dashboard summary card (always visible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _DashboardCard(
                    c: c,
                    offers: _offers,
                    accountCount: _paymentMethods.length,
                    animCtrl: _heroCtrl,
                  ),
                ),

                // ── Warning banner
                if (_paymentMethods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _AlertBanner(
                      c: c,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No active payment method',
                      body: 'Enable at least one payment method before posting offers.',
                      accent: c.warning,
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Custom Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TabBar(c: c, controller: _tabCtrl),
                ),

                const SizedBox(height: 16),

                // ── Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── Tab 1: Create Offer
                      RefreshIndicator(
                        onRefresh: _load,
                        color: c.primary,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          children: [
                            _CreateOfferCard(
                              c: c,
                              assets: assets,
                              selectedAssetSymbol: resolvedAsset,
                              fiatCode: fiat,
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
                              syncingAvailableQty: _syncingAvailableQty,
                              onTypeChanged: (v)   => setState(() => _type = v),
                              onAssetChanged: (v)  {
                                setState(() => _selectedAssetSymbol = v);
                                _syncAvailableQty();
                              },
                              onMethodChanged: (v) => setState(() => _selectedPaymentMethod = v),
                              onReceiverWalletChanged: (v) {
                                setState(() => _selectedReceiverWallet = v);
                                _syncAvailableQty();
                              },
                              onVisibleChanged: (v) => setState(() => _isVisible = v),
                              onSyncAvailableQty: _syncAvailableQty,
                              onSubmit: _createOffer,
                            ),
                          ],
                        ),
                      ),

                      // ── Tab 2: My Offers
                      RefreshIndicator(
                        onRefresh: _load,
                        color: c.primary,
                        child: _offers.isEmpty
                            ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          children: [_EmptyOffersCard(c: c)],
                        )
                            : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: _offers.length,
                          itemBuilder: (_, i) => _AnimatedOfferTile(
                            index: i,
                            c: c,
                            offer: _offers[i],
                            onPauseOrResume: () => _pauseOrResume(_offers[i]),
                            onCancel: () => _cancel(_offers[i]),
                          ),
                        ),
                      ),
                    ],
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
// SCREEN HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.c, required this.onRefresh});
  final AppColor c;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(
        children: [
          if (canPop) ...[
            _IconBtn(c: c, icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Offers',
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
                  'Configure your marketplace presence',
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
          _RefreshBtn(c: c, onTap: onRefresh),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM TAB BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatefulWidget {
  const _TabBar({required this.c, required this.controller});
  final AppColor c;
  final TabController controller;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final idx = widget.controller.index;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _TabOption(
            c: c,
            label: 'Create Offer',
            icon: Icons.add_rounded,
            active: idx == 0,
            onTap: () { HapticFeedback.selectionClick(); widget.controller.animateTo(0); },
          ),
          const SizedBox(width: 3),
          _TabOption(
            c: c,
            label: 'My Offers',
            icon: Icons.list_alt_rounded,
            active: idx == 1,
            onTap: () { HapticFeedback.selectionClick(); widget.controller.animateTo(1); },
          ),
        ],
      ),
    );
  }
}

class _TabOption extends StatelessWidget {
  const _TabOption({
    required this.c,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final AppColor c;
  final String label;
  final IconData icon;
  final bool active;
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
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: c.primary.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE ICON BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.c, required this.icon, required this.onTap});
  final AppColor c;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: Icon(icon, size: 17, color: c.textSecondary),
    ),
  );
}

class _RefreshBtn extends StatefulWidget {
  const _RefreshBtn({required this.c, required this.onTap});
  final AppColor c;
  final VoidCallback onTap;

  @override
  State<_RefreshBtn> createState() => _RefreshBtnState();
}

class _RefreshBtnState extends State<_RefreshBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _ctrl.forward(from: 0); widget.onTap(); },
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: widget.c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.c.border.withOpacity(0.25)),
        ),
        child: RotationTransition(
          turns: _ctrl,
          child: Icon(Icons.refresh_rounded, size: 17, color: widget.c.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
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
    final active  = offers.where((o) => o.status == OfferStatus.active).length;
    final paused  = offers.where((o) => o.status == OfferStatus.paused).length;
    final total   = offers.length;
    final progress = total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(color: c.primary.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'MERCHANT',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: c.border.withOpacity(0.2)),
                ),
                child: Text(
                  '$total total',
                  style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Title
          Text(
            'Your Marketplace\nOffers',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 16),

          // ── Stat chips
          Row(
            children: [
              _StatChip(c: c, value: '$active',       label: 'Active',   accent: c.success),
              const SizedBox(width: 8),
              _StatChip(c: c, value: '$paused',       label: 'Paused',   accent: c.warning),
              const SizedBox(width: 8),
              _StatChip(c: c, value: '$accountCount', label: 'Accounts', accent: c.primary),
            ],
          ),

          const SizedBox(height: 18),

          // ── Progress bar
          Row(
            children: [
              Text(
                'ACTIVITY',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: animCtrl,
                builder: (_, __) => Text(
                  total == 0 ? '–' : '${(progress * 100).toStringAsFixed(0)}% active',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          AnimatedBuilder(
            animation: animCtrl,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(animCtrl.value);
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress * t,
                  minHeight: 6,
                  backgroundColor: c.border.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(c.primary),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.c, required this.value, required this.label, required this.accent});
  final AppColor c;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withOpacity(0.14)),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: accent.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
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
    required this.syncingAvailableQty,
    required this.onTypeChanged,
    required this.onAssetChanged,
    required this.onMethodChanged,
    required this.onReceiverWalletChanged,
    required this.onVisibleChanged,
    required this.onSyncAvailableQty,
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
  final bool syncingAvailableQty;
  final ValueChanged<OfferType> onTypeChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<PaymentMethodModel?> onMethodChanged;
  final ValueChanged<WalletAddress?> onReceiverWalletChanged;
  final ValueChanged<bool> onVisibleChanged;
  final Future<void> Function({bool silent}) onSyncAvailableQty;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TypeToggle(c: c, selected: type, onChanged: onTypeChanged),
          ),

          _HDivider(c: c),

          // ── Form fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Asset & Currency
                _FormGroup(
                  c: c,
                  label: 'Asset & Currency',
                  child: Row(
                    children: [
                      Expanded(
                        child: _Dropdown<String>(
                          c: c,
                          value: selectedAssetSymbol,
                          hint: 'Asset',
                          icon: Icons.generating_tokens_rounded,
                          items: assets.map((a) => DropdownMenuItem(
                            value: a.symbol.toUpperCase(),
                            child: Text(a.symbol.toUpperCase()),
                          )).toList(),
                          onChanged: onAssetChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _FiatPicker(c: c, fiatCode: fiatCode)),
                    ],
                  ),
                ),

                // Margin
                _FormGroup(
                  c: c,
                  label: 'Price Margin',
                  child: _MarginField(c: c, controller: marginCtrl),
                ),

                // Trade limits
                _FormGroup(
                  c: c,
                  label: 'Trade Limits',
                  child: Row(
                    children: [
                      Expanded(child: _Field(c: c, controller: minCtrl, hint: 'Min amount', icon: Icons.south_rounded, isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _Field(c: c, controller: maxCtrl, hint: 'Max amount', icon: Icons.north_rounded, isNumber: true)),
                    ],
                  ),
                ),

                // Quantity & Window
                _FormGroup(
                  c: c,
                  label: 'Quantity & Payment Window',
                  sublabel: 'Auto-synced',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _Field(c: c, controller: totalQtyCtrl, hint: 'Total qty', icon: Icons.inventory_2_outlined, isNumber: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _Field(c: c, controller: availableQtyCtrl, hint: 'Available qty (live)', icon: Icons.dataset_outlined, isNumber: true, readOnly: true)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            syncingAvailableQty
                                ? 'Syncing from Stellar wallet...'
                                : 'Available qty is based on on-chain wallet balance.',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: syncingAvailableQty
                                ? null
                                : () => onSyncAvailableQty(silent: false),
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text('Sync'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Field(c: c, controller: paymentWindowCtrl, hint: 'Payment window (minutes)', icon: Icons.timer_outlined, isNumber: true),
                    ],
                  ),
                ),

                // Receiver wallet
                _FormGroup(
                  c: c,
                  label: 'Receiver Wallet',
                  sublabel: 'Optional',
                  child: _Dropdown<WalletAddress>(
                    c: c,
                    value: selectedReceiverWallet,
                    hint: wallets.isEmpty ? 'No wallet available' : 'Select wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    items: wallets.map((w) => DropdownMenuItem<WalletAddress>(
                      value: w,
                      child: Text(_walletLabel(w), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: onReceiverWalletChanged,
                  ),
                ),

                // Auto reply
                _FormGroup(
                  c: c,
                  label: 'Auto Reply Message',
                  sublabel: 'Optional',
                  child: _Field(
                    c: c,
                    controller: autoReplyCtrl,
                    hint: 'Greeting shown to buyers when trade starts',
                    icon: Icons.chat_bubble_outline_rounded,
                    maxLines: 2,
                  ),
                ),

                // Payment method
                _FormGroup(
                  c: c,
                  label: 'Payment Method',
                  child: _Dropdown<PaymentMethodModel>(
                    c: c,
                    value: selectedMethod,
                    hint: 'Select method',
                    icon: Icons.account_balance_rounded,
                    items: methods.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('${m.name} (${m.code})', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: onMethodChanged,
                  ),
                ),
              ],
            ),
          ),

          _HDivider(c: c),

          // ── Visibility + submit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                _VisibilityRow(c: c, isVisible: isVisible, onChanged: onVisibleChanged),
                const SizedBox(height: 14),
                _SubmitBtn(c: c, submitting: submitting, type: type, onSubmit: onSubmit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _walletLabel(WalletAddress w) {
    final label  = (w.label ?? '').trim();
    final addr   = w.publicAddress;
    final short  = addr.length > 14
        ? '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}'
        : addr;
    final prefix = w.isActive ? '✦ Active' : 'Wallet';
    return label.isNotEmpty ? '$prefix · $label · $short' : '$prefix · $short';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM GROUP WRAPPER — adds consistent label + spacing
// ─────────────────────────────────────────────────────────────────────────────

class _FormGroup extends StatelessWidget {
  const _FormGroup({
    required this.c,
    required this.label,
    required this.child,
    this.sublabel,
  });
  final AppColor c;
  final String label;
  final String? sublabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.textSecondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sublabel!,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE TOGGLE
// ─────────────────────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.c, required this.selected, required this.onChanged});
  final AppColor c;
  final OfferType selected;
  final ValueChanged<OfferType> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: c.border.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        _TypeOption(
          c: c,
          label: 'BUY',
          icon: Icons.south_west_rounded,
          active: selected == OfferType.buy,
          activeColor: c.success,
          onTap: () { HapticFeedback.selectionClick(); onChanged(OfferType.buy); },
        ),
        const SizedBox(width: 4),
        _TypeOption(
          c: c,
          label: 'SELL',
          icon: Icons.north_east_rounded,
          active: selected == OfferType.sell,
          activeColor: c.primary,
          onTap: () { HapticFeedback.selectionClick(); onChanged(OfferType.sell); },
        ),
      ],
    ),
  );
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
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
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: activeColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : c.textSecondary),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: active ? Colors.white : c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.6,
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
// FORM FIELD COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.c,
    required this.controller,
    required this.hint,
    this.icon,
    this.isNumber = false,
    this.maxLines = 1,
    this.readOnly = false,
  });
  final AppColor c;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool isNumber;
  final int maxLines;
  final bool readOnly;

  InputDecoration _dec() => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w400),
    prefixIcon: icon != null ? Icon(icon, size: 16, color: c.textSecondary.withOpacity(0.6)) : null,
    filled: true,
    fillColor: c.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.primary, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    maxLines: maxLines,
    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
    decoration: _dec(),
  );
}

class _MarginField extends StatelessWidget {
  const _MarginField({required this.c, required this.controller});
  final AppColor c;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    decoration: InputDecoration(
      hintText: '0',
      hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.3), fontSize: 22, fontWeight: FontWeight.w800),
      suffixText: '%',
      suffixStyle: TextStyle(color: c.primary, fontSize: 20, fontWeight: FontWeight.w800),
      filled: true,
      fillColor: c.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.primary, width: 1.5)),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
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
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary.withOpacity(0.6), size: 20),
    items: items,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.5), fontSize: 13),
      prefixIcon: Icon(icon, size: 16, color: c.textSecondary.withOpacity(0.6)),
      filled: true,
      fillColor: c.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.primary, width: 1.5)),
    ),
    style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
    dropdownColor: c.surface,
  );
}

class _FiatPicker extends StatelessWidget {
  const _FiatPicker({required this.c, required this.fiatCode});
  final AppColor c;
  final String fiatCode;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); showFiatPickerBottomSheet(context); },
    child: Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.border.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.paid_outlined, size: 16, color: c.textSecondary.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fiatCode,
                style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: c.textSecondary.withOpacity(0.6), size: 20),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VISIBILITY ROW
// ─────────────────────────────────────────────────────────────────────────────

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({required this.c, required this.isVisible, required this.onChanged});
  final AppColor c;
  final bool isVisible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
    decoration: BoxDecoration(
      color: isVisible ? c.primary.withOpacity(0.05) : c.background,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(
        color: isVisible ? c.primary.withOpacity(0.2) : c.border.withOpacity(0.2),
      ),
    ),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            key: ValueKey(isVisible),
            size: 17,
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
                style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                isVisible ? 'Visible to buyers' : 'Hidden from marketplace',
                style: TextStyle(color: c.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: isVisible,
          onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); },
          activeColor: c.primary,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitBtn extends StatelessWidget {
  const _SubmitBtn({required this.c, required this.submitting, required this.type, required this.onSubmit});
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
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: submitting ? null : [
            BoxShadow(color: color.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: ElevatedButton(
          onPressed: submitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.45),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: submitting
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))),
                const SizedBox(width: 10),
                const Text('Creating offer…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isBuy ? Icons.south_west_rounded : Icons.north_east_rounded, size: 16),
                const SizedBox(width: 8),
                Text(
                  isBuy ? 'Post Buy Offer' : 'Post Sell Offer',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: -0.2),
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
// OFFER TILE (animated)
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
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 380 + widget.index * 55),
  );
  late final Animation<double>  _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset>  _slide = Tween<Offset>(
    begin: const Offset(0, 0.12), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 55), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
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

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.c, required this.offer, required this.onPauseOrResume, required this.onCancel});
  final AppColor c;
  final OfferModel offer;
  final VoidCallback onPauseOrResume;
  final VoidCallback onCancel;

  bool get _isBuy => offer.type == OfferType.buy;

  Color _accent(OfferStatus? s) => switch (s) {
    OfferStatus.active    => c.success,
    OfferStatus.paused    => c.warning,
    OfferStatus.completed => c.primary,
    OfferStatus.cancelled => c.error,
    _                     => c.textSecondary,
  };

  String _fmt(dynamic v) {
    if (v == null) return '–';
    if (v is double) return v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isBuy      = _isBuy;
    final typeColor  = isBuy ? c.success : c.primary;
    final accent     = _accent(offer.status);
    final canToggle  = offer.status == OfferStatus.active || offer.status == OfferStatus.paused;
    final isActive   = offer.status == OfferStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? accent.withOpacity(0.25) : c.border.withOpacity(0.18),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // Type badge
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [typeColor.withOpacity(0.15), typeColor.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeColor.withOpacity(0.15)),
                  ),
                  child: Icon(isBuy ? Icons.south_west_rounded : Icons.north_east_rounded, size: 18, color: typeColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isBuy ? 'BUY' : 'SELL'} ${offer.asset}/${offer.fiatCurrency}',
                        style: TextStyle(
                          color: c.textPrimary, fontSize: 14.5,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Margin ${offer.marginPercent ?? 0}%',
                        style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 5, spreadRadius: 1)],
                          ),
                        ),
                      Text(
                        (offer.status?.name ?? 'unknown').toUpperCase(),
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Metrics strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.border.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                _Metric(c: c, label: 'MIN',    value: _fmt(offer.minAmount)),
                _MetricSep(c: c),
                _Metric(c: c, label: 'MAX',    value: _fmt(offer.maxAmount)),
                _MetricSep(c: c),
                _Metric(c: c, label: 'MARGIN', value: '${_fmt(offer.marginPercent)}%'),
                _MetricSep(c: c),
                _Metric(
                  c: c,
                  label: 'SUCCESS',
                  value: offer.successRate != null
                      ? '${offer.successRate!.toStringAsFixed(1)}%'
                      : '–',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                if (canToggle) ...[
                  Expanded(
                    child: _ActionBtn(
                      c: c,
                      label: offer.status == OfferStatus.active ? 'Pause' : 'Resume',
                      icon: offer.status == OfferStatus.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: c.textPrimary,
                      bg: c.textPrimary.withOpacity(0.06),
                      border: c.border.withOpacity(0.25),
                      onTap: onPauseOrResume,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _ActionBtn(
                  c: c,
                  label: 'Cancel',
                  icon: Icons.close_rounded,
                  color: c.error,
                  bg: c.error.withOpacity(0.06),
                  border: c.error.withOpacity(0.2),
                  onTap: onCancel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.c, required this.label, required this.value});
  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _MetricSep extends StatelessWidget {
  const _MetricSep({required this.c});
  final AppColor c;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: c.border.withOpacity(0.25));
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.c,
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.border,
    required this.onTap,
  });
  final AppColor c;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY OFFERS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyOffersCard extends StatelessWidget {
  const _EmptyOffersCard({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.border.withOpacity(0.18)),
    ),
    child: Column(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.storefront_outlined, color: c.primary, size: 24),
        ),
        const SizedBox(height: 14),
        Text('No offers yet',
            style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(
          'Create your first offer above to\nstart trading on the marketplace.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.c, required this.icon, required this.title, required this.body, required this.accent});
  final AppColor c;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withOpacity(0.18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accent, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.1)),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL DIVIDER
// ─────────────────────────────────────────────────────────────────────────────

class _HDivider extends StatelessWidget {
  const _HDivider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 14),
    height: 1,
    color: c.border.withOpacity(0.12),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.c, required this.error, required this.onRetry});
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
            width: 56, height: 56,
            decoration: BoxDecoration(color: c.error.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.cloud_off_rounded, color: c.error, size: 26),
          ),
          const SizedBox(height: 18),
          Text('Something went wrong',
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
