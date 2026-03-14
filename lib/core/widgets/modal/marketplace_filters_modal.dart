import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/modal/show_fiat_picker_bottom_sheet.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

Future<MarketOfferFilters?> showMarketplaceFiltersModal(
  BuildContext context, {
  required MarketOfferFilters initialFilters,
  required List<PaymentMethodModel> paymentMethods,
}) {
  return showModalBottomSheet<MarketOfferFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColor.of(context).surface,
    builder: (_) => _MarketplaceFiltersSheet(
      initialFilters: initialFilters,
      paymentMethods: paymentMethods,
      currentFiatCode: ProviderScope.containerOf(
        context,
        listen: false,
      ).read(currencyVmProvider).fiatCode,
    ),
  );
}

class MarketOfferFilters {
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

  const MarketOfferFilters({
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

  MarketOfferFilters copyWith({
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
    return MarketOfferFilters(
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

  MarketOfferFilters normalized() {
    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return MarketOfferFilters(
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

  String summary(List<PaymentMethodModel> methods) {
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
    if (sortBy != null) parts.add('Sort ${_sortLabel(sortBy!)}');
    if ((sellerId ?? '').isNotEmpty) parts.add('Seller');
    if ((receiverStellarAddress ?? '').isNotEmpty) parts.add('Receiver');
    return parts.isEmpty
        ? 'Search, amount, payment method, sort'
        : parts.join(' | ');
  }

  @override
  bool operator ==(Object other) {
    return other is MarketOfferFilters &&
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

class _MarketplaceFiltersSheet extends StatefulWidget {
  const _MarketplaceFiltersSheet({
    required this.initialFilters,
    required this.paymentMethods,
    required this.currentFiatCode,
  });

  final MarketOfferFilters initialFilters;
  final List<PaymentMethodModel> paymentMethods;
  final String currentFiatCode;

  @override
  State<_MarketplaceFiltersSheet> createState() =>
      _MarketplaceFiltersSheetState();
}

class _MarketplaceFiltersSheetState extends State<_MarketplaceFiltersSheet> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _minAmountCtrl;
  late final TextEditingController _maxAmountCtrl;
  late final TextEditingController _sellerCtrl;
  late final TextEditingController _receiverCtrl;

  late MarketOfferFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.copyWith(
      fiatCurrency:
          widget.initialFilters.fiatCurrency ?? widget.currentFiatCode,
    );
    _qCtrl = TextEditingController(text: _filters.q ?? '');
    _amountCtrl = TextEditingController(text: _filters.amount ?? '');
    _minAmountCtrl = TextEditingController(text: _filters.minAmount ?? '');
    _maxAmountCtrl = TextEditingController(text: _filters.maxAmount ?? '');
    _sellerCtrl = TextEditingController(text: _filters.sellerId ?? '');
    _receiverCtrl = TextEditingController(
      text: _filters.receiverStellarAddress ?? '',
    );
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _amountCtrl.dispose();
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    _sellerCtrl.dispose();
    _receiverCtrl.dispose();
    super.dispose();
  }

  Future<void> _close([MarketOfferFilters? result]) async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _apply() {
    _close(
      _filters
          .copyWith(
            q: _qCtrl.text,
            fiatCurrency: _filters.fiatCurrency,
            amount: _amountCtrl.text,
            minAmount: _minAmountCtrl.text,
            maxAmount: _maxAmountCtrl.text,
            sellerId: _sellerCtrl.text,
            receiverStellarAddress: _receiverCtrl.text,
          )
          .normalized(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final activeCount = _filters
        .copyWith(
          q: _qCtrl.text,
          amount: _amountCtrl.text,
          minAmount: _minAmountCtrl.text,
          maxAmount: _maxAmountCtrl.text,
          sellerId: _sellerCtrl.text,
          receiverStellarAddress: _receiverCtrl.text,
        )
        .normalized()
        .activeCount;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketplace Filters',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Refine offers by asset, amount, payment method, and seller details.',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: activeCount > 0
                        ? c.primary.withValues(alpha: 0.10)
                        : c.border.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: activeCount > 0
                          ? c.primary.withValues(alpha: 0.20)
                          : c.border.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$activeCount',
                        style: TextStyle(
                          color: activeCount > 0 ? c.primary : c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        activeCount == 1 ? 'filter' : 'filters',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FilterSectionCard(
              c: c,
              label: 'DISCOVER',
              title: 'Find matching offers quickly',
              description:
                  'Start with what you know most: search terms, asset, fiat currency, and amount.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModalField(
                    controller: _qCtrl,
                    label: 'Search',
                    hint: 'Asset, fiat, seller name, email',
                    icon: Icons.search_rounded,
                    action: TextInputAction.next,
                    helper:
                        'Search by asset, currency, or seller details to find offers faster.',
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  _SegmentRow<String>(
                    label: 'Asset',
                    value: _filters.asset,
                    options: const ['XLM', 'USDC'],
                    labelBuilder: (value) => value,
                    onChanged: (value) => setState(() {
                      _filters = _filters.copyWith(asset: value);
                    }),
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  _ModalDropdown<String?>(
                    value: _filters.fiatCurrency,
                    label: 'Fiat Currency',
                    icon: Icons.payments_outlined,
                    helper:
                        'Starts with your current app currency and can be changed for this search.',
                    c: c,
                    items: [
                      ...kFiatOptions.map(
                        (fiat) => DropdownMenuItem<String?>(
                          value: fiat.code.toUpperCase(),
                          child: Text(
                            '${fiat.flag} ${fiat.code.toUpperCase()}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _filters = _filters.copyWith(fiatCurrency: value);
                    }),
                  ),
                  const SizedBox(height: 14),
                  _ModalField(
                    controller: _amountCtrl,
                    label: 'Amount',
                    hint: 'Match min <= amount <= max',
                    icon: Icons.calculate_outlined,
                    action: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    helper:
                        'Show offers that can handle the amount you plan to trade.',
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ModalField(
                          controller: _minAmountCtrl,
                          label: 'Min Amount',
                          hint: 'Range overlap start',
                          icon: Icons.south_west_rounded,
                          action: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          c: c,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModalField(
                          controller: _maxAmountCtrl,
                          label: 'Max Amount',
                          hint: 'Range overlap end',
                          icon: Icons.north_east_rounded,
                          action: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          c: c,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FilterSectionCard(
              c: c,
              label: 'PREFERENCE',
              title: 'Choose how offers are ranked',
              description:
                  'Focus on the payment method you can use and the order you want to browse results.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModalDropdown<String?>(
                    value: _filters.paymentMethodId,
                    label: 'Payment Method',
                    icon: Icons.account_balance_outlined,
                    c: c,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All payment methods'),
                      ),
                      ...widget.paymentMethods.map(
                        (method) => DropdownMenuItem<String?>(
                          value: method.id,
                          child: Text(method.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _filters = _filters.copyWith(paymentMethodId: value);
                    }),
                  ),
                  const SizedBox(height: 14),
                  _ModalDropdown<OfferSortBy?>(
                    value: _filters.sortBy,
                    label: 'Sort By',
                    icon: Icons.sort_rounded,
                    c: c,
                    items: [
                      const DropdownMenuItem<OfferSortBy?>(
                        value: null,
                        child: Text('Recommended default'),
                      ),
                      ...OfferSortBy.values.map(
                        (sort) => DropdownMenuItem<OfferSortBy?>(
                          value: sort,
                          child: Text(_sortLabel(sort)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _filters = _filters.copyWith(sortBy: value);
                    }),
                  ),
                  const SizedBox(height: 14),
                  _SegmentRow<OfferSortOrder>(
                    label: 'Sort Order',
                    value: _filters.sortOrder,
                    options: OfferSortOrder.values,
                    labelBuilder: (value) =>
                        value.name[0].toUpperCase() + value.name.substring(1),
                    onChanged: (value) => setState(() {
                      _filters = _filters.copyWith(sortOrder: value);
                    }),
                    c: c,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FilterSectionCard(
              c: c,
              label: 'ADVANCED',
              title: 'Target a specific seller or wallet',
              description:
                  'Use these only when you want to narrow results to a known seller or receiver address.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModalField(
                    controller: _sellerCtrl,
                    label: 'Seller ID',
                    hint: 'Only show one seller',
                    icon: Icons.storefront_outlined,
                    action: TextInputAction.next,
                    helper:
                        'Use this when you already know the seller you want to trade with.',
                    c: c,
                  ),
                  const SizedBox(height: 14),
                  _ModalField(
                    controller: _receiverCtrl,
                    label: 'Receiver Stellar Address',
                    hint: 'Only show one receiver address',
                    icon: Icons.account_balance_wallet_outlined,
                    action: TextInputAction.done,
                    helper:
                        'Useful when you want offers linked to a specific wallet address.',
                    c: c,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.border.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.border.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(const MarketOfferFilters()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: BorderSide(
                          color: c.border.withValues(alpha: 0.85),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        activeCount > 0
                            ? 'Apply $activeCount Filters'
                            : 'Apply Filters',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionCard extends StatelessWidget {
  const _FilterSectionCard({
    required this.c,
    required this.label,
    required this.title,
    required this.description,
    required this.child,
  });

  final AppColor c;
  final String label;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: label, c: c),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ModalField extends StatefulWidget {
  const _ModalField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.action,
    required this.c,
    this.keyboardType,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputAction action;
  final AppColor c;
  final TextInputType? keyboardType;
  final String? helper;

  @override
  State<_ModalField> createState() => _ModalFieldState();
}

class _ModalFieldState extends State<_ModalField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final activeBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.primary, width: 1.5),
    );
    final idleBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: c.border.withValues(alpha: 0.28),
        width: 1.2,
      ),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.action,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: c.textSecondary.withValues(alpha: 0.4),
          fontSize: 13.5,
        ),
        labelStyle: TextStyle(
          color: _focused ? c.primary : c.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: _focused ? c.primary : c.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        helperText: widget.helper,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: c.textSecondary.withValues(alpha: 0.82),
          fontSize: 11.5,
          height: 1.35,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            widget.icon,
            size: 17,
            color: _focused
                ? c.primary
                : c.textSecondary.withValues(alpha: 0.5),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _focused
            ? c.primary.withValues(alpha: 0.03)
            : c.border.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        border: idleBorder,
        enabledBorder: idleBorder,
        focusedBorder: activeBorder,
      ),
    );
  }
}

class _ModalDropdown<T> extends StatelessWidget {
  const _ModalDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.c,
    this.helper,
  });

  final T value;
  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppColor c;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: c.textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            icon,
            size: 17,
            color: c.textSecondary.withValues(alpha: 0.5),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: c.border.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: c.border.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: c.border.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        helperText: helper,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: c.textSecondary.withValues(alpha: 0.82),
          fontSize: 11.5,
          height: 1.35,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(13),
          dropdownColor: c.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.c});

  final String label;
  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: c.textSecondary.withValues(alpha: 0.6),
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
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
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = option == value;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(option);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: active ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: active
                        ? c.primary
                        : c.border.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  labelBuilder(option),
                  style: TextStyle(
                    color: active ? c.onPrimary : c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

