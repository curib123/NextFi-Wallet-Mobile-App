import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/features/merchant_offers/view/merchant_offer_editor_screen.dart';
import 'package:next_fi/features/merchant_request/view/merchant_request_screen.dart';
import 'package:next_fi/features/merchant_trades/view/merchant_trades_screen.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/profile/profile_core_service.dart';

class MerchantOffersScreen extends StatefulWidget {
  const MerchantOffersScreen({super.key});

  @override
  State<MerchantOffersScreen> createState() => _MerchantOffersScreenState();
}

class _MerchantOffersScreenState extends State<MerchantOffersScreen> {
  final _offers = OffersCoreService.I;
  final _profile = ProfileCoreService.I;
  final _searchCtrl = TextEditingController();
  final _fiatCtrl = TextEditingController(text: 'PHP');
  final _money = NumberFormat.currency(symbol: '', decimalDigits: 2);

  OfferType _type = OfferType.sell;
  OfferAsset _asset = OfferAsset.usdc;
  bool _loading = true;
  bool _isMerchant = false;
  String? _error;
  String? _busyOfferId;
  List<OfferModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fiatCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
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
      await _loadOffers(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadOffers({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final query = OffersQuery(
        type: _type,
        asset: _asset,
        fiatCurrency: _fiatCtrl.text.trim().isEmpty ? 'PHP' : _fiatCtrl.text,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        page: 1,
        limit: 100,
      );
      final items = await _offers.listMyOffers(query);
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

  Future<void> _openCreate() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MerchantOfferEditorScreen()),
    );
    if (changed == true && mounted) {
      await _loadOffers(showLoader: true);
    }
  }

  Future<void> _openEdit(OfferModel offer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MerchantOfferEditorScreen(initialOffer: offer),
      ),
    );
    if (changed == true && mounted) {
      await _loadOffers(showLoader: true);
    }
  }

  Future<void> _toggleActive(OfferModel offer) async {
    if (_busyOfferId != null) return;
    setState(() => _busyOfferId = offer.id);
    try {
      await _offers.patchMyOffer(
        offer.id,
        UpdateOfferRequest(isActive: !offer.isActive),
      );
      if (!mounted) return;
      await _loadOffers(showLoader: false);
      _showSnack(offer.isActive ? 'Offer paused.' : 'Offer activated.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _deleteOffer(OfferModel offer) async {
    if (_busyOfferId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        final c = AppColor.of(context);
        return AlertDialog(
          backgroundColor: c.surface,
          title: const Text('Delete Offer'),
          content: const Text('This action will remove the offer permanently.'),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            AppElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _busyOfferId = offer.id);
    try {
      await _offers.deleteMyOffer(offer.id);
      if (!mounted) return;
      await _loadOffers(showLoader: false);
      _showSnack('Offer deleted.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _priceLabel(OfferModel offer) {
    if (offer.priceType == OfferPriceType.fixed && offer.fixedPrice != null) {
      return '${_money.format(offer.fixedPrice)} ${offer.fiatCurrency}';
    }
    if (offer.priceType == OfferPriceType.floating &&
        offer.marginPercent != null) {
      final sign = offer.marginPercent! >= 0 ? '+' : '';
      return 'Market $sign${offer.marginPercent!.toStringAsFixed(2)}%';
    }
    return 'Price not available';
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
          'Merchant Offers',
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
              onRefresh: () => _loadOffers(showLoader: false),
              color: c.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  _HeroCard(
                    c: c,
                    onCreateOffer: _openCreate,
                    onOpenTrades: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MerchantTradesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(c: c, label: 'FILTERS'),
                  const SizedBox(height: 8),
                  _FilterCard(
                    c: c,
                    searchCtrl: _searchCtrl,
                    fiatCtrl: _fiatCtrl,
                    type: _type,
                    asset: _asset,
                    onSearch: () => _loadOffers(showLoader: true),
                    onTypeChanged: (v) {
                      setState(() => _type = v);
                      _loadOffers(showLoader: true);
                    },
                    onAssetChanged: (v) {
                      setState(() => _asset = v);
                      _loadOffers(showLoader: true);
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(c: c, label: 'MY OFFERS'),
                  const SizedBox(height: 8),
                  if (_error != null) ...[
                    _ErrorCard(c: c, message: _error!, onRetry: _bootstrap),
                  ] else if (_items.isEmpty) ...[
                    _EmptyCard(c: c, onCreateOffer: _openCreate),
                  ] else ...[
                    ..._items.map(
                      (offer) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OfferCard(
                          c: c,
                          offer: offer,
                          busy: _busyOfferId == offer.id,
                          priceLabel: _priceLabel(offer),
                          onEdit: () => _openEdit(offer),
                          onToggle: () => _toggleActive(offer),
                          onDelete: () => _deleteOffer(offer),
                        ),
                      ),
                    ),
                  ],
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
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Only merchant accounts can create and manage offers. Submit a merchant request to continue.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.8,
                  height: 1.42,
                ),
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
    required this.onCreateOffer,
    required this.onOpenTrades,
  });

  final AppColor c;
  final VoidCallback onCreateOffer;
  final VoidCallback onOpenTrades;

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
              'MERCHANT HUB',
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
            'Manage offers and monitor incoming trades',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'When a buyer clicks your offer and starts chat, the trade appears in Merchant Trades.',
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
                child: AppElevatedButton.icon(
                  onPressed: onCreateOffer,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppOutlinedButton.icon(
                  onPressed: onOpenTrades,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Trade Inbox'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border.withOpacity(0.35)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
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
    required this.fiatCtrl,
    required this.type,
    required this.asset,
    required this.onSearch,
    required this.onTypeChanged,
    required this.onAssetChanged,
  });

  final AppColor c;
  final TextEditingController searchCtrl;
  final TextEditingController fiatCtrl;
  final OfferType type;
  final OfferAsset asset;
  final VoidCallback onSearch;
  final ValueChanged<OfferType> onTypeChanged;
  final ValueChanged<OfferAsset> onAssetChanged;

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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search by asset, fiat, note',
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
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 86,
                child: TextField(
                  controller: fiatCtrl,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'FIAT',
                    filled: true,
                    fillColor: c.background,
                    border: fieldBorder(),
                    enabledBorder: fieldBorder(),
                    focusedBorder: fieldFocused(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FilterChip(
                c: c,
                selected: type == OfferType.buy,
                label: 'BUY',
                onTap: () => onTypeChanged(OfferType.buy),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                c: c,
                selected: type == OfferType.sell,
                label: 'SELL',
                onTap: () => onTypeChanged(OfferType.sell),
              ),
              const Spacer(),
              _FilterChip(
                c: c,
                selected: asset == OfferAsset.usdc,
                label: 'USDC',
                onTap: () => onAssetChanged(OfferAsset.usdc),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                c: c,
                selected: asset == OfferAsset.xlm,
                label: 'XLM',
                onTap: () => onAssetChanged(OfferAsset.xlm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.c,
    required this.offer,
    required this.busy,
    required this.priceLabel,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AppColor c;
  final OfferModel offer;
  final bool busy;
  final String priceLabel;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final methods = offer.paymentMethods
        .map((e) => e.name.trim().isEmpty ? e.code : e.name)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final methodsLabel = methods.isEmpty
        ? 'No methods'
        : methods.take(3).join(' | ');
    final statusColor = offer.isActive ? c.success : c.textSecondary;

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
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  offerTypeToApi(offer.type),
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  offer.isActive ? 'Active' : 'Paused',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${offerAssetToApi(offer.asset)}/${offer.fiatCurrency}',
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
            priceLabel,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Limits ${offer.minAmount.toStringAsFixed(2)} - ${offer.maxAmount.toStringAsFixed(2)}',
            style: TextStyle(color: c.textSecondary, fontSize: 12.4),
          ),
          const SizedBox(height: 2),
          Text(
            'Qty ${offer.remainingQty?.toStringAsFixed(2) ?? '-'} / ${offer.totalQty?.toStringAsFixed(2) ?? '-'} | Window ${offer.paymentWindow} mins',
            style: TextStyle(color: c.textSecondary, fontSize: 12.4),
          ),
          const SizedBox(height: 2),
          Text(
            methodsLabel,
            style: TextStyle(color: c.textSecondary, fontSize: 12.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border.withOpacity(0.35)),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextButton.icon(
                  onPressed: busy ? null : onToggle,
                  icon: Icon(
                    offer.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(offer.isActive ? 'Pause' : 'Activate'),
                  style: TextButton.styleFrom(
                    foregroundColor: c.primary,
                    backgroundColor: c.primary.withOpacity(0.08),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: AppTextButton.icon(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: c.error,
                    backgroundColor: c.error.withOpacity(0.08),
                    minimumSize: const Size(90, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
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
            'Failed to load offers.',
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
  const _EmptyCard({required this.c, required this.onCreateOffer});

  final AppColor c;
  final VoidCallback onCreateOffer;

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
          Icon(LucideIcons.listX, size: 18, color: c.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No offers yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first offer to start receiving trades from buyers.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          AppElevatedButton.icon(
            onPressed: onCreateOffer,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Offer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(136, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
