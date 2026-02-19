import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';

class MerchantOfferEditorScreen extends StatefulWidget {
  const MerchantOfferEditorScreen({super.key, this.initialOffer});

  final OfferModel? initialOffer;

  bool get isEdit => initialOffer != null;

  @override
  State<MerchantOfferEditorScreen> createState() =>
      _MerchantOfferEditorScreenState();
}

class _MerchantOfferEditorScreenState extends State<MerchantOfferEditorScreen> {
  final _offers = OffersCoreService.I;
  final _payments = PaymentMethodAndAccountsCoreService.I;

  final _fiatCtrl = TextEditingController(text: 'PHP');
  final _fixedPriceCtrl = TextEditingController();
  final _marginCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _windowCtrl = TextEditingController(text: '15');
  final _autoReplyCtrl = TextEditingController();

  OfferType _type = OfferType.sell;
  OfferAsset _asset = OfferAsset.usdc;
  OfferPriceType _priceType = OfferPriceType.fixed;
  bool _requiredReady = true;
  bool _isActive = true;

  bool _loadingMethods = true;
  bool _saving = false;
  String? _error;

  List<PaymentMethodModel> _methods = const [];
  final Set<String> _selectedMethodIds = <String>{};

  bool get _isEdit => widget.isEdit;
  OfferModel? get _initial => widget.initialOffer;

  @override
  void initState() {
    super.initState();
    _hydrateFromInitial();
    _loadMethods();
  }

  @override
  void dispose() {
    _fiatCtrl.dispose();
    _fixedPriceCtrl.dispose();
    _marginCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _totalCtrl.dispose();
    _windowCtrl.dispose();
    _autoReplyCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromInitial() {
    final offer = _initial;
    if (offer == null) return;

    _type = offer.type == OfferType.unknown ? OfferType.sell : offer.type;
    _asset = offer.asset == OfferAsset.unknown ? OfferAsset.usdc : offer.asset;
    _priceType = offer.priceType == OfferPriceType.unknown
        ? OfferPriceType.fixed
        : offer.priceType;
    _requiredReady = offer.requiredReady;
    _isActive = offer.isActive;

    _fiatCtrl.text = offer.fiatCurrency.trim().isEmpty
        ? 'PHP'
        : offer.fiatCurrency.trim().toUpperCase();
    _fixedPriceCtrl.text = offer.fixedPrice?.toString() ?? '';
    _marginCtrl.text = offer.marginPercent?.toString() ?? '';
    _minCtrl.text = offer.minAmount.toString();
    _maxCtrl.text = offer.maxAmount.toString();
    _totalCtrl.text = (offer.totalQty ?? offer.maxAmount).toString();
    _windowCtrl.text = offer.paymentWindow.toString();
    _autoReplyCtrl.text = offer.autoReply ?? '';

    for (final method in offer.paymentMethods) {
      final id = method.id.trim();
      if (id.isNotEmpty) {
        _selectedMethodIds.add(id);
      }
    }
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loadingMethods = true;
      _error = null;
    });
    try {
      final methods = await _payments.listPaymentMethods(activeOnly: true);
      methods.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loadingMethods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMethods = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    final fiat = _fiatCtrl.text.trim().toUpperCase();
    if (fiat.length < 3) {
      _showSnack('Enter a valid fiat code, for example PHP.');
      return;
    }

    final minAmount = double.tryParse(_minCtrl.text.trim());
    final maxAmount = double.tryParse(_maxCtrl.text.trim());
    final totalQty = double.tryParse(_totalCtrl.text.trim());
    final paymentWindow = int.tryParse(_windowCtrl.text.trim());
    final fixedPrice = double.tryParse(_fixedPriceCtrl.text.trim());
    final marginPercent = double.tryParse(_marginCtrl.text.trim());

    if (minAmount == null || maxAmount == null || totalQty == null) {
      _showSnack('Enter valid numeric values for min, max, and total.');
      return;
    }
    if (minAmount <= 0 || maxAmount <= 0 || totalQty <= 0) {
      _showSnack('Amounts must be greater than zero.');
      return;
    }
    if (minAmount > maxAmount) {
      _showSnack('Min amount must be less than or equal to max amount.');
      return;
    }
    if (maxAmount > totalQty) {
      _showSnack('Max amount cannot be greater than total quantity.');
      return;
    }
    if (paymentWindow == null || paymentWindow < 5 || paymentWindow > 120) {
      _showSnack('Payment window must be between 5 and 120 minutes.');
      return;
    }

    if (_priceType == OfferPriceType.fixed) {
      if (fixedPrice == null || fixedPrice <= 0) {
        _showSnack('Enter a valid fixed price.');
        return;
      }
    }
    if (_priceType == OfferPriceType.floating) {
      if (marginPercent == null) {
        _showSnack('Enter a margin percent for floating price.');
        return;
      }
    }

    if (_selectedMethodIds.isEmpty) {
      _showSnack('Select at least one payment method.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _offers.patchMyOffer(
          _initial!.id,
          UpdateOfferRequest(
            priceType: _priceType,
            fixedPrice: _priceType == OfferPriceType.fixed ? fixedPrice : null,
            marginPercent: _priceType == OfferPriceType.floating
                ? marginPercent
                : null,
            minAmount: minAmount,
            maxAmount: maxAmount,
            totalQty: totalQty,
            paymentWindow: paymentWindow,
            requiredReady: _requiredReady,
            isActive: _isActive,
            paymentMethodIds: _selectedMethodIds.toList(),
            autoReply: _autoReplyCtrl.text.trim(),
          ),
        );
      } else {
        await _offers.createMyOffer(
          CreateOfferRequest(
            type: _type,
            asset: _asset,
            fiatCurrency: fiat,
            priceType: _priceType,
            fixedPrice: _priceType == OfferPriceType.fixed ? fixedPrice : null,
            marginPercent: _priceType == OfferPriceType.floating
                ? marginPercent
                : null,
            minAmount: minAmount,
            maxAmount: maxAmount,
            totalQty: totalQty,
            paymentWindow: paymentWindow,
            requiredReady: _requiredReady,
            paymentMethodIds: _selectedMethodIds.toList(),
            autoReply: _autoReplyCtrl.text.trim().isEmpty
                ? null
                : _autoReplyCtrl.text.trim(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          _isEdit ? 'Edit Offer' : 'Create Offer',
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          _HeroCard(
            c: c,
            title: _isEdit ? 'Update merchant offer' : 'Create merchant offer',
            subtitle:
                'Use active payment methods and valid limits. Changes apply to your trade listing immediately.',
            badge: _isEdit ? 'EDIT MODE' : 'CREATE MODE',
          ),
          const SizedBox(height: 18),
          _SectionLabel(c: c, label: 'MARKET'),
          const SizedBox(height: 8),
          _SurfaceCard(
            c: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEdit) ...[
                  _ReadOnlyRow(
                    c: c,
                    label: 'Type',
                    value: offerTypeToApi(_type),
                  ),
                  _ReadOnlyRow(
                    c: c,
                    label: 'Asset',
                    value: offerAssetToApi(_asset),
                  ),
                  _ReadOnlyRow(
                    c: c,
                    label: 'Fiat',
                    value: _fiatCtrl.text.trim().toUpperCase(),
                  ),
                ] else ...[
                  _ChoiceRow<OfferType>(
                    c: c,
                    title: 'Type',
                    value: _type,
                    options: const [
                      (OfferType.buy, 'BUY'),
                      (OfferType.sell, 'SELL'),
                    ],
                    onChanged: (value) => setState(() => _type = value),
                  ),
                  const SizedBox(height: 8),
                  _ChoiceRow<OfferAsset>(
                    c: c,
                    title: 'Asset',
                    value: _asset,
                    options: const [
                      (OfferAsset.usdc, 'USDC'),
                      (OfferAsset.xlm, 'XLM'),
                    ],
                    onChanged: (value) => setState(() => _asset = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fiatCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Fiat currency',
                      hintText: 'PHP',
                      filled: true,
                      fillColor: c.background,
                      border: _fieldBorder(c),
                      enabledBorder: _fieldBorder(c),
                      focusedBorder: _fieldFocusedBorder(c),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(c: c, label: 'PRICING'),
          const SizedBox(height: 8),
          _SurfaceCard(
            c: c,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChoiceRow<OfferPriceType>(
                  c: c,
                  title: 'Price type',
                  value: _priceType,
                  options: const [
                    (OfferPriceType.fixed, 'FIXED'),
                    (OfferPriceType.floating, 'FLOATING'),
                  ],
                  onChanged: (value) => setState(() => _priceType = value),
                ),
                const SizedBox(height: 10),
                if (_priceType == OfferPriceType.fixed)
                  TextField(
                    controller: _fixedPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Fixed price',
                      hintText: '56.20',
                      filled: true,
                      fillColor: c.background,
                      border: _fieldBorder(c),
                      enabledBorder: _fieldBorder(c),
                      focusedBorder: _fieldFocusedBorder(c),
                    ),
                  )
                else
                  TextField(
                    controller: _marginCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Margin percent',
                      hintText: '1.50 or -0.50',
                      filled: true,
                      fillColor: c.background,
                      border: _fieldBorder(c),
                      enabledBorder: _fieldBorder(c),
                      focusedBorder: _fieldFocusedBorder(c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(c: c, label: 'LIMITS'),
          const SizedBox(height: 8),
          _SurfaceCard(
            c: c,
            child: Column(
              children: [
                _TwoFieldRow(
                  c: c,
                  leftLabel: 'Min amount',
                  leftController: _minCtrl,
                  rightLabel: 'Max amount',
                  rightController: _maxCtrl,
                ),
                const SizedBox(height: 10),
                _TwoFieldRow(
                  c: c,
                  leftLabel: 'Total quantity',
                  leftController: _totalCtrl,
                  rightLabel: 'Payment window (mins)',
                  rightController: _windowCtrl,
                  rightKeyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(c: c, label: 'PAYMENT METHODS'),
          const SizedBox(height: 8),
          _SurfaceCard(
            c: c,
            child: _loadingMethods
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _methods.map((method) {
                          final selected = _selectedMethodIds.contains(
                            method.id,
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedMethodIds.remove(method.id);
                                } else {
                                  _selectedMethodIds.add(method.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? c.primary.withOpacity(0.1)
                                    : c.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? c.primary.withOpacity(0.4)
                                      : c.border.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                method.name.trim().isEmpty
                                    ? method.code
                                    : method.name,
                                style: TextStyle(
                                  color: selected ? c.primary : c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.3,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_methods.isEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'No active payment methods available.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.4,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(c: c, label: 'SAFETY'),
          const SizedBox(height: 8),
          _SurfaceCard(
            c: c,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requiredReady,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _requiredReady = value),
                  title: Text(
                    'Require verified buyer',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isEdit)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isActive,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isActive = value),
                    title: Text(
                      'Offer is active',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextField(
                  controller: _autoReplyCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Auto reply (optional)',
                    hintText: 'Payment instructions for buyers.',
                    filled: true,
                    fillColor: c.background,
                    border: _fieldBorder(c),
                    enabledBorder: _fieldBorder(c),
                    focusedBorder: _fieldFocusedBorder(c),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.error.withOpacity(0.2)),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: c.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _saving
                  ? null
                  : [
                      BoxShadow(
                        color: c.primary.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: AppElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _saving
                    ? 'Saving...'
                    : (_isEdit ? 'Update Offer' : 'Create Offer'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(AppColor c) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.border.withOpacity(0.24)),
    );
  }

  OutlineInputBorder _fieldFocusedBorder(AppColor c) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: c.primary.withOpacity(0.42), width: 1.2),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.c,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final AppColor c;
  final String title;
  final String subtitle;
  final String badge;

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
              badge,
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
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.7,
              height: 1.4,
            ),
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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.c, required this.child});

  final AppColor c;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withOpacity(0.25)),
      ),
      child: child,
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.c,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final AppColor c;
  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((entry) {
            final selected = entry.$1 == value;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(entry.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? c.primary.withOpacity(0.1) : c.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? c.primary.withOpacity(0.4)
                        : c.border.withOpacity(0.24),
                  ),
                ),
                child: Text(
                  entry.$2,
                  style: TextStyle(
                    color: selected ? c.primary : c.textPrimary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
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

class _TwoFieldRow extends StatelessWidget {
  const _TwoFieldRow({
    required this.c,
    required this.leftLabel,
    required this.leftController,
    required this.rightLabel,
    required this.rightController,
    this.rightKeyboardType = const TextInputType.numberWithOptions(
      decimal: true,
    ),
  });

  final AppColor c;
  final String leftLabel;
  final TextEditingController leftController;
  final String rightLabel;
  final TextEditingController rightController;
  final TextInputType rightKeyboardType;

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

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: leftController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: leftLabel,
              filled: true,
              fillColor: c.background,
              border: fieldBorder(),
              enabledBorder: fieldBorder(),
              focusedBorder: fieldFocused(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: rightController,
            keyboardType: rightKeyboardType,
            decoration: InputDecoration(
              labelText: rightLabel,
              filled: true,
              fillColor: c.background,
              border: fieldBorder(),
              enabledBorder: fieldBorder(),
              focusedBorder: fieldFocused(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.c,
    required this.label,
    required this.value,
  });

  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
