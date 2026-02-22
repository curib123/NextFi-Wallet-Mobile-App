import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/common/components/modal/showFiatPickerBottomSheet.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/services/merchant_payment_account/merchant_payment_account_core_service.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:provider/provider.dart';

class ManageOffersScreen extends StatefulWidget {
  const ManageOffersScreen({super.key});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen>
    with SingleTickerProviderStateMixin {
  final _offersCore = OffersCoreService.I;
  final _merchantPaymentsCore = MerchantPaymentAccountCoreService.I;

  bool _loading = true;
  bool _submitting = false;
  List<OfferModel> _offers = const [];
  List<MerchantPaymentAccountModel> _merchantAccounts = const [];
  String? _error;

  final _marginCtrl = TextEditingController(text: '0');
  final _minCtrl = TextEditingController(text: '0');
  final _maxCtrl = TextEditingController(text: '0');
  final _autoReplyCtrl = TextEditingController();
  OfferType _type = OfferType.sell;
  MerchantPaymentAccountModel? _selectedAccount;
  String? _selectedAssetSymbol;
  bool _isVisible = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _marginCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _autoReplyCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await _merchantPaymentsCore.listAll(activeOnly: true);
      final offers = await _offersCore.listMine(
        query: const OffersListQuery(page: 1, limit: 50),
      );
      if (!mounted) return;
      setState(() {
        _merchantAccounts = accounts;
        _selectedAccount = accounts.isEmpty ? null : accounts.first;
        _offers = offers;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createOffer() async {
    final account = _selectedAccount;
    if (account == null) {
      _showSnack('Select a merchant payment account first.');
      return;
    }

    final assets = context.read<AssetVM>().assets;
    if (assets.isEmpty) {
      _showSnack('No assets available for offer creation.');
      return;
    }
    final fallbackAsset = assets.first.symbol.toUpperCase();
    final asset = (_selectedAssetSymbol ?? fallbackAsset).trim().toUpperCase();
    final fiat = context.read<CurrencyVM>().fiat.trim().toUpperCase();
    final margin = double.tryParse(_marginCtrl.text.trim());
    final minAmount = double.tryParse(_minCtrl.text.trim());
    final maxAmount = double.tryParse(_maxCtrl.text.trim());
    if (asset.isEmpty || fiat.isEmpty) {
      _showSnack('Asset and fiat currency are required.');
      return;
    }
    if (margin == null || minAmount == null || maxAmount == null) {
      _showSnack('Margin, min and max amount must be valid numbers.');
      return;
    }
    if (maxAmount < minAmount) {
      _showSnack('Max amount must be greater than or equal to min amount.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _offersCore.create(
        CreateOfferRequest(
          type: _type,
          asset: asset,
          fiatCurrency: fiat,
          marginPercent: margin,
          minAmount: minAmount,
          maxAmount: maxAmount,
          autoReply: _autoReplyCtrl.text.trim().isEmpty
              ? null
              : _autoReplyCtrl.text.trim(),
          isVisible: _isVisible,
          paymentMethodIds: [account.paymentMethodId],
        ),
      );
      _marginCtrl.text = '0';
      _minCtrl.text = '0';
      _maxCtrl.text = '0';
      _autoReplyCtrl.clear();
      if (!mounted) return;
      _showSnack('Offer created.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to create offer: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pauseOrResume(OfferModel offer) async {
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
      _showSnack('Failed to update offer state: $e');
    }
  }

  Future<void> _cancel(OfferModel offer) async {
    try {
      await _offersCore.cancel(offer.id);
      if (!mounted) return;
      _showSnack('Offer cancelled.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to cancel offer: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Manage Offers',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _loading
          ? const PageLoader(label: 'Loading offers...')
          : _error != null
              ? _ErrorState(c: c, error: _error!, onRetry: _load)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: c.primary,
                    backgroundColor: c.surface,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                      children: [
                        _OffersHeroCard(
                          c: c,
                          offers: _offers,
                          accountCount: _merchantAccounts.length,
                        ),
                        if (_merchantAccounts.isEmpty) ...[
                          const SizedBox(height: 10),
                          _NoticeBanner(
                            c: c,
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'No Merchant Payment Account',
                            body:
                                'Create and activate a merchant payment account before posting offers.',
                            accent: c.warning,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _SectionHeader(c: c, label: 'Create Offer'),
                        const SizedBox(height: 10),
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
                          autoReplyCtrl: _autoReplyCtrl,
                          type: _type,
                          accounts: _merchantAccounts,
                          selectedAccount: _selectedAccount,
                          isVisible: _isVisible,
                          submitting: _submitting,
                          onTypeChanged: (v) => setState(() => _type = v),
                          onAssetChanged: (v) =>
                              setState(() => _selectedAssetSymbol = v),
                          onAccountChanged: (v) =>
                              setState(() => _selectedAccount = v),
                          onVisibleChanged: (v) =>
                              setState(() => _isVisible = v),
                          onSubmit: _createOffer,
                        ),
                        const SizedBox(height: 22),
                        _SectionHeader(c: c, label: 'My Offers'),
                        const SizedBox(height: 10),
                        if (_offers.isEmpty)
                          _EmptyOffersCard(c: c)
                        else
                          ..._offers.map(
                            (offer) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OfferTile(
                                c: c,
                                offer: offer,
                                onPauseOrResume: () => _pauseOrResume(offer),
                                onCancel: () => _cancel(offer),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _CreateOfferCard extends StatelessWidget {
  const _CreateOfferCard({
    required this.c,
    required this.assets,
    required this.selectedAssetSymbol,
    required this.fiatCode,
    required this.marginCtrl,
    required this.minCtrl,
    required this.maxCtrl,
    required this.autoReplyCtrl,
    required this.type,
    required this.accounts,
    required this.selectedAccount,
    required this.isVisible,
    required this.submitting,
    required this.onTypeChanged,
    required this.onAssetChanged,
    required this.onAccountChanged,
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
  final TextEditingController autoReplyCtrl;
  final OfferType type;
  final List<MerchantPaymentAccountModel> accounts;
  final MerchantPaymentAccountModel? selectedAccount;
  final bool isVisible;
  final bool submitting;
  final ValueChanged<OfferType> onTypeChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<MerchantPaymentAccountModel?> onAccountChanged;
  final ValueChanged<bool> onVisibleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
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
              Expanded(
                child: _SimpleTypeChip(
                  c: c,
                  selected: type == OfferType.buy,
                  label: 'BUY',
                  onTap: () => onTypeChanged(OfferType.buy),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SimpleTypeChip(
                  c: c,
                  selected: type == OfferType.sell,
                  label: 'SELL',
                  onTap: () => onTypeChanged(OfferType.sell),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedAssetSymbol,
            items: assets
                .map(
                  (a) => DropdownMenuItem<String>(
                    value: a.symbol.toUpperCase(),
                    child: Text('${a.symbol.toUpperCase()} (${a.name})'),
                  ),
                )
                .toList(),
            onChanged: onAssetChanged,
            decoration: InputDecoration(
              labelText: 'Asset',
              filled: true,
              fillColor: c.background.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showFiatPickerBottomSheet(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: c.background.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fiat Currency: $fiatCode',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Field(c: c, controller: marginCtrl, label: 'Margin %', isNumber: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Field(c: c, controller: minCtrl, label: 'Min amount', isNumber: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(c: c, controller: maxCtrl, label: 'Max amount', isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Field(c: c, controller: autoReplyCtrl, label: 'Auto reply (optional)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<MerchantPaymentAccountModel>(
            value: selectedAccount,
            items: accounts
                .map((a) => DropdownMenuItem<MerchantPaymentAccountModel>(
                      value: a,
                      child: Text(_accountLabel(a)),
                    ))
                .toList(),
            onChanged: onAccountChanged,
            decoration: InputDecoration(
              labelText: 'Merchant payment account',
              filled: true,
              fillColor: c.background.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.border.withOpacity(0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: c.primary, width: 1.4),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Visible in marketplace',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ),
              Switch.adaptive(
                value: isVisible,
                onChanged: onVisibleChanged,
                activeColor: c.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: submitting
                  ? null
                  : [
                      BoxShadow(
                        color: c.primary.withOpacity(0.26),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppElevatedButton(
                onPressed: submitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.primary.withOpacity(0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
                          const Text('Creating...'),
                        ],
                      )
                    : const Text(
                        'Create Offer',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _accountLabel(MerchantPaymentAccountModel account) {
    final methodName = (account.paymentMethod?['name'] ?? '')
        .toString()
        .trim();
    final label = (account.label ?? '').trim();
    final accountNo = (account.accountNo ?? '').trim();
    final primary = label.isNotEmpty ? label : account.accountName;
    final tail = <String>[
      if (methodName.isNotEmpty) methodName,
      if (accountNo.isNotEmpty) accountNo,
    ].join(' · ');
    return tail.isEmpty ? primary : '$primary · $tail';
  }
}

class _SimpleTypeChip extends StatelessWidget {
  const _SimpleTypeChip({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected ? c.primary.withOpacity(0.12) : c.background.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? c.primary.withOpacity(0.35) : c.border.withOpacity(0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.primary : c.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.c,
    required this.controller,
    required this.label,
    this.isNumber = false,
  });

  final AppColor c;
  final TextEditingController controller;
  final String label;
  final bool isNumber;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: c.background.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.4),
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
    final canPauseResume =
        status == OfferStatus.active || status == OfferStatus.paused;
    final accent = _statusAccent(c, status);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  offer.type == OfferType.buy
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${offer.type == OfferType.buy ? 'BUY' : 'SELL'} ${offer.asset}/${offer.fiatCurrency}',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status?.name.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Margin: ${offer.marginPercent ?? '-'}% · Min: ${offer.minAmount ?? '-'} · Max: ${offer.maxAmount ?? '-'}',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canPauseResume)
                AppOutlinedButton(
                  onPressed: onPauseOrResume,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border.withOpacity(0.32)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(status == OfferStatus.active ? 'Pause' : 'Resume'),
                ),
              const SizedBox(width: 8),
              AppOutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.error,
                  side: BorderSide(color: c.error.withOpacity(0.35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
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

class _EmptyOffersCard extends StatelessWidget {
  const _EmptyOffersCard({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
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
            child: Icon(Icons.post_add_rounded, color: c.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No offers yet. Create your first one above.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.c, required this.label});

  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 17),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
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

class _OffersHeroCard extends StatelessWidget {
  const _OffersHeroCard({
    required this.c,
    required this.offers,
    required this.accountCount,
  });

  final AppColor c;
  final List<OfferModel> offers;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        offers.where((o) => o.status == OfferStatus.active).length;
    final pausedCount =
        offers.where((o) => o.status == OfferStatus.paused).length;
    final total = offers.length;
    final progress = total == 0 ? 0.0 : (activeCount / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
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
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'MERCHANT',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$total offers',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Manage your marketplace offers',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$activeCount active · $pausedCount paused · $accountCount payment account(s)',
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: c.border.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            const SizedBox(height: 16),
            Text(
              'Couldn\'t Load Offers',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
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
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppFilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
