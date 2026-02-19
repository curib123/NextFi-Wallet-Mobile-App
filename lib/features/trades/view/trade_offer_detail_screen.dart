import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/features/trades/view/trade_order_screen.dart';
import 'package:next_fi/features/trades/view/trade_template_screen.dart';
import 'package:next_fi/features/verification_flow/view/payment_method_setup_screen.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/offers/offers_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';

class TradeOfferDetailScreen extends StatefulWidget {
  const TradeOfferDetailScreen({
    super.key,
    required this.mode,
    required this.offer,
  });

  final TradeTemplateMode mode;
  final OfferModel offer;

  @override
  State<TradeOfferDetailScreen> createState() => _TradeOfferDetailScreenState();
}

class _TradeOfferDetailScreenState extends State<TradeOfferDetailScreen> {
  final _offers = OffersCoreService.I;
  final _payments = PaymentMethodAndAccountsCoreService.I;
  final _trades = TradesCoreService.I;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _money = NumberFormat.currency(symbol: '', decimalDigits: 2);

  OfferModel? _offer;
  List<UserPaymentAccountModel> _myAccounts = const [];
  List<UserPaymentAccountModel> _sellerAccounts = const [];
  UserPaymentAccountModel? _buyerAccount;
  UserPaymentAccountModel? _sellerAccount;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  bool get _isBuy => widget.mode == TradeTemplateMode.buy;

  @override
  void initState() {
    super.initState();
    _offer = widget.offer;
    _bootstrap();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _offers.getPublicOffer(widget.offer.id),
        _payments.listMyPaymentAccounts(activeOnly: true),
      ]);
      final fullOffer = results[0] as OfferModel;
      final myAccounts = results[1] as List<UserPaymentAccountModel>;

      if (!mounted) return;
      setState(() {
        _offer = fullOffer;
        _myAccounts = myAccounts;
        _buyerAccount = myAccounts.isNotEmpty ? myAccounts.first : null;
        _sellerAccounts = fullOffer.sellerPaymentAccounts;
        _sellerAccount = _sellerAccounts.isNotEmpty
            ? _sellerAccounts.first
            : null;
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

  String _priceLabel(OfferModel offer) {
    if (offer.priceType == OfferPriceType.fixed && offer.fixedPrice != null) {
      return '${_money.format(offer.fixedPrice)} ${offer.fiatCurrency}';
    }
    if (offer.priceType == OfferPriceType.floating &&
        offer.marginPercent != null) {
      return 'Market ${offer.marginPercent! >= 0 ? '+' : ''}${offer.marginPercent!.toStringAsFixed(2)}%';
    }
    return 'Price not available';
  }

  Future<void> _continue() async {
    final offer = _offer;
    if (offer == null || _submitting) return;

    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount.');
      return;
    }
    if (amount < offer.minAmount || amount > offer.maxAmount) {
      _showSnack(
        'Amount must be between ${offer.minAmount.toStringAsFixed(2)} and ${offer.maxAmount.toStringAsFixed(2)} ${offer.fiatCurrency}.',
      );
      return;
    }
    if (_buyerAccount == null) {
      _showSnack('Select your payment account.');
      return;
    }
    if (_sellerAccount == null) {
      _showSnack('This offer has no seller payment account configured.');
      return;
    }

    final confirmed = await _showConfirmSheet(
      context,
      offer: offer,
      amount: amount,
      buyerAccount: _buyerAccount!,
      sellerAccount: _sellerAccount!,
      note: _noteCtrl.text.trim(),
      isBuy: _isBuy,
      money: _money,
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final trade = await _trades.createTrade(
        CreateTradeRequest(
          offerId: offer.id,
          amount: amount,
          sellerPaymentAccountId: _sellerAccount!.id,
          buyerPaymentAccountId: _buyerAccount!.id,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TradeOrderScreen(
            tradeId: trade.id,
            asSeller: false,
            mode: widget.mode,
          ),
        ),
        result: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(e.toString());
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
    final offer = _offer;

    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: c.error, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.8),
                    ),
                    const SizedBox(height: 12),
                    AppOutlinedButton(
                      onPressed: _bootstrap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border.withOpacity(0.5)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : offer == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: [
                  _OfferOverviewCard(
                    offer: offer,
                    c: c,
                    priceLabel: _priceLabel(offer),
                  ),
                  const SizedBox(height: 10),
                  _ClaimableProtectionCard(c: c),
                  const SizedBox(height: 18),
                  Text(
                    'TRADE SETUP',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border.withOpacity(0.25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Trade',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (${offer.fiatCurrency})',
                            hintText:
                                '${offer.minAmount.toStringAsFixed(2)} - ${offer.maxAmount.toStringAsFixed(2)}',
                            filled: true,
                            fillColor: c.background,
                            border: _fieldBorder(c),
                            enabledBorder: _fieldBorder(c),
                            focusedBorder: _fieldFocusedBorder(c),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _noteCtrl,
                          minLines: 2,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Note (optional)',
                            hintText: 'Payment note for merchant',
                            filled: true,
                            fillColor: c.background,
                            border: _fieldBorder(c),
                            enabledBorder: _fieldBorder(c),
                            focusedBorder: _fieldFocusedBorder(c),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_myAccounts.isEmpty)
                          _MissingAccountNotice(c: c)
                        else
                          DropdownButtonFormField<UserPaymentAccountModel>(
                            value: _buyerAccount,
                            isExpanded: true,
                            items: _myAccounts
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      '${e.paymentMethod?.name ?? 'Method'} | ${e.accountName}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _buyerAccount = v),
                            decoration: InputDecoration(
                              labelText: 'Your payment account',
                              filled: true,
                              fillColor: c.background,
                              border: _fieldBorder(c),
                              enabledBorder: _fieldBorder(c),
                              focusedBorder: _fieldFocusedBorder(c),
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (_sellerAccounts.isEmpty)
                          _NoSellerAccountNotice(c: c)
                        else
                          DropdownButtonFormField<UserPaymentAccountModel>(
                            value: _sellerAccount,
                            isExpanded: true,
                            items: _sellerAccounts
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      '${e.paymentMethod?.name ?? 'Method'} | ${e.accountName}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _sellerAccount = v),
                            decoration: InputDecoration(
                              labelText: 'Seller payment account',
                              filled: true,
                              fillColor: c.background,
                              border: _fieldBorder(c),
                              enabledBorder: _fieldBorder(c),
                              focusedBorder: _fieldFocusedBorder(c),
                            ),
                          ),
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _submitting
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
                            onPressed: _submitting ? null : _continue,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                  ),
                            label: Text(
                              _submitting
                                  ? 'Creating trade...'
                                  : 'Confirm & Continue',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColor c) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        _isBuy ? 'Buy Offer' : 'Sell Offer',
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

class _OfferOverviewCard extends StatelessWidget {
  const _OfferOverviewCard({
    required this.offer,
    required this.c,
    required this.priceLabel,
  });

  final OfferModel offer;
  final AppColor c;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    final methods = offer.paymentMethods
        .map((e) => e.name.trim().isEmpty ? e.code : e.name)
        .where((e) => e.trim().isNotEmpty)
        .join(' | ');
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LIVE OFFER',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.shieldCheck, size: 15, color: c.success),
              const SizedBox(width: 4),
              Text(
                'Escrow Protected',
                style: TextStyle(
                  color: c.success,
                  fontSize: 11.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${offerAssetToApi(offer.asset)}/${offer.fiatCurrency}',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            priceLabel,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Limits ${offer.minAmount.toStringAsFixed(2)} - ${offer.maxAmount.toStringAsFixed(2)} ${offer.fiatCurrency}',
            style: TextStyle(color: c.textSecondary, fontSize: 12.6),
          ),
          const SizedBox(height: 3),
          Text(
            'Payment window ${offer.paymentWindow} minutes',
            style: TextStyle(color: c.textSecondary, fontSize: 12.6),
          ),
          if (methods.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              methods,
              style: TextStyle(
                color: c.textPrimary.withOpacity(0.85),
                fontSize: 12.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimableProtectionCard extends StatelessWidget {
  const _ClaimableProtectionCard({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.success.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: c.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claimable Balance Protection',
                  style: TextStyle(
                    color: c.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anti-scam protection is enabled: this trade uses claimable-balance escrow. Do not release or confirm outside the official flow.',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.3,
                    height: 1.35,
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

class _MissingAccountNotice extends StatelessWidget {
  const _MissingAccountNotice({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.warning.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.warning.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set up your payment account first.',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12.6,
            ),
          ),
          const SizedBox(height: 6),
          AppTextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PaymentMethodSetupScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Open payment account setup'),
          ),
        ],
      ),
    );
  }
}

class _NoSellerAccountNotice extends StatelessWidget {
  const _NoSellerAccountNotice({required this.c});

  final AppColor c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.error.withOpacity(0.2)),
      ),
      child: Text(
        'Seller payment account is not available for this offer. Choose another offer.',
        style: TextStyle(color: c.textPrimary, fontSize: 12.3),
      ),
    );
  }
}

Future<bool?> _showConfirmSheet(
  BuildContext context, {
  required OfferModel offer,
  required double amount,
  required UserPaymentAccountModel buyerAccount,
  required UserPaymentAccountModel sellerAccount,
  required String note,
  required bool isBuy,
  required NumberFormat money,
}) {
  final c = AppColor.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.border.withOpacity(0.25)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Confirm Trade',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _ConfirmRow(
                c: c,
                label: 'Flow',
                value: isBuy ? 'Buy from SELL offer' : 'Sell to BUY offer',
              ),
              _ConfirmRow(
                c: c,
                label: 'Asset',
                value:
                    '${offerAssetToApi(offer.asset)} / ${offer.fiatCurrency}',
              ),
              _ConfirmRow(
                c: c,
                label: 'Amount',
                value: '${money.format(amount)} ${offer.fiatCurrency}',
              ),
              _ConfirmRow(
                c: c,
                label: 'Your account',
                value:
                    '${buyerAccount.paymentMethod?.name ?? 'Method'} | ${buyerAccount.accountName}',
              ),
              _ConfirmRow(
                c: c,
                label: 'Seller account',
                value:
                    '${sellerAccount.paymentMethod?.name ?? 'Method'} | ${sellerAccount.accountName}',
              ),
              if (note.isNotEmpty)
                _ConfirmRow(c: c, label: 'Note', value: note),
              const SizedBox(height: 12),
              AppElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                fullWidth: true,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Create Trade'),
              ),
              const SizedBox(height: 8),
              AppTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                fullWidth: true,
                style: TextButton.styleFrom(
                  foregroundColor: c.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.c,
    required this.label,
    required this.value,
  });

  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
