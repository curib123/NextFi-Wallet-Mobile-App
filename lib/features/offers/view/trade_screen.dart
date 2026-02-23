import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/merchant_payment_account/merchant_payment_account_core_service.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_dtos.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/offer_payment_method/offer_payment_method_core_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:next_fi/services/wallet/models/wallet_models.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, required this.offer});

  final OfferModel offer;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fiatCtrl = TextEditingController();
  final _tradesCore = TradesCoreService.I;
  final _walletCore = WalletCoreService.I;
  final _offerPaymentCore = OfferPaymentMethodCoreService.I;
  final _merchantAccountCore = MerchantPaymentAccountCoreService.I;
  final _userAccountCore = PaymentMethodAndAccountsCoreService.I;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  List<PaymentMethodModel> _offerPaymentMethods = [];
  List<MerchantPaymentAccountModel> _merchantAccounts = [];
  List<WalletAddress> _wallets = [];
  List<UserPaymentAccountModel> _userAccounts = [];

  PaymentMethodModel? _selectedOfferMethod;
  MerchantPaymentAccountModel? _selectedMerchantAccount;
  WalletAddress? _selectedWallet;
  UserPaymentAccountModel? _selectedUserAccount;

  double _computedCrypto = 0;

  OfferModel get offer => widget.offer;

  // User is buyer if offer type is SELL (merchant sells → user buys)
  bool get _userIsBuyer => offer.type == OfferType.sell;

  @override
  void initState() {
    super.initState();
    _fiatCtrl.addListener(_onFiatChanged);
    _loadData();
  }

  @override
  void dispose() {
    _fiatCtrl.removeListener(_onFiatChanged);
    _fiatCtrl.dispose();
    super.dispose();
  }

  void _onFiatChanged() {
    final v = double.tryParse(_fiatCtrl.text.trim()) ?? 0;
    final rate = offer.marginPercent != null ? (1 + offer.marginPercent! / 100) : 1.0;
    setState(() => _computedCrypto = rate > 0 ? v / rate : v);
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final results = await Future.wait([
        _offerPaymentCore.getPaymentMethodsForOffer(offer.id),
        _walletCore.list(),
        _userAccountCore.listMyPaymentAccounts(activeOnly: true),
        _loadMerchantAccounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _offerPaymentMethods = results[0] as List<PaymentMethodModel>;
        _wallets = results[1] as List<WalletAddress>;
        _userAccounts = results[2] as List<UserPaymentAccountModel>;
        _merchantAccounts = results[3] as List<MerchantPaymentAccountModel>;
        final wallets = _wallets;
        if (wallets.isNotEmpty) {
          _selectedWallet = wallets.firstWhere(
            (w) => w.isActive,
            orElse: () => wallets.first,
          );
        }
        final pm = _offerPaymentMethods;
        if (pm.isNotEmpty) _selectedOfferMethod = pm.first;
        _loading = false;
      });
      _refreshMerchantAccountsForMethod();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  Future<List<MerchantPaymentAccountModel>> _loadMerchantAccounts() async {
    try {
      final sellerId = offer.sellerId ?? '';
      if (sellerId.isEmpty) return [];
      final resp = await _merchantAccountCore.listPaged(
        query: MerchantPaymentAccountListQuery(
          activeOnly: true,
          limit: 50,
          sellerId: sellerId,
        ),
      );
      return resp.items;
    } catch (_) {
      return [];
    }
  }

  void _refreshMerchantAccountsForMethod() {
    if (_selectedOfferMethod == null) return;
    final methodId = _selectedOfferMethod!.id;
    final filtered = _merchantAccounts
        .where((a) => a.paymentMethodId == methodId && a.isActive)
        .toList();
    setState(() {
      _selectedMerchantAccount = filtered.isNotEmpty ? filtered.first : null;
    });
  }

  String? _validateFiat(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return 'Invalid amount';
    final min = offer.minAmount;
    final max = offer.maxAmount;
    if (min != null && parsed < min) {
      return 'Minimum is ${offer.fiatCurrency} $min';
    }
    if (max != null && parsed > max) {
      return 'Maximum is ${offer.fiatCurrency} $max';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWallet == null) {
      showFloatingSnackBar(context,
          message: 'No wallet address found. Please add a wallet first.',
          type: SnackBarType.error);
      return;
    }
    if (_selectedMerchantAccount == null && _userIsBuyer) {
      showFloatingSnackBar(context,
          message: 'No payment account available for this method.',
          type: SnackBarType.warning);
    }

    final fiatAmount = _fiatCtrl.text.trim();
    final cryptoAmount = _computedCrypto.toStringAsFixed(7);

    // For seller account ID, try merchant account or use placeholder
    final sellAccId = _selectedMerchantAccount?.id ?? '';
    if (sellAccId.isEmpty) {
      showFloatingSnackBar(context,
          message: 'Could not resolve seller payment account.',
          type: SnackBarType.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      final trade = await _tradesCore.create(
        CreateTradeRequest(
          offerId: offer.id,
          sellerPaymentAccountId: sellAccId,
          buyerPaymentAccountId: _selectedUserAccount?.id,
          cryptoAmount: cryptoAmount,
          fiatAmount: fiatAmount,
          cryptoReceiverAddress: _selectedWallet!.publicAddress,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TradeOrderScreen(trade: trade, offer: offer)),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('TradeApiException')) {
        msg = msg.replaceAll(RegExp(r'TradeApiException\(\d+\): '), '');
      }
      showFloatingSnackBar(context,
          message: msg, type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isBuy = _userIsBuyer;
    final typeColor = isBuy ? const Color(0xFF00C48C) : const Color(0xFF6C6FFF);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          isBuy ? 'Buy ${offer.asset}' : 'Sell ${offer.asset}',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: _loading
          ? _LoadingBody(c: c)
          : _loadError != null
              ? _ErrorBody(c: c, error: _loadError!, onRetry: _loadData)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // ── Offer summary ──────────────────────────────────
                      _OfferSummaryCard(c: c, offer: offer, typeColor: typeColor),
                      const SizedBox(height: 14),

                      // ── Amount input ───────────────────────────────────
                      _SectionLabel(c: c, label: isBuy ? 'You pay (fiat)' : 'You receive (fiat)'),
                      const SizedBox(height: 8),
                      _AmountField(
                        c: c,
                        controller: _fiatCtrl,
                        currency: offer.fiatCurrency,
                        validator: _validateFiat,
                        min: offer.minAmount,
                        max: offer.maxAmount,
                      ),
                      if (_computedCrypto > 0) ...[
                        const SizedBox(height: 8),
                        _CryptoEquivalentRow(
                          c: c,
                          asset: offer.asset,
                          amount: _computedCrypto,
                          typeColor: typeColor,
                        ),
                      ],
                      const SizedBox(height: 18),

                      // ── Merchant payment account (where to send fiat) ──
                      if (isBuy && _offerPaymentMethods.isNotEmpty) ...[
                        _SectionLabel(c: c, label: 'Pay via'),
                        const SizedBox(height: 8),
                        _PaymentMethodSelector(
                          c: c,
                          methods: _offerPaymentMethods,
                          selected: _selectedOfferMethod,
                          onChanged: (m) {
                            setState(() => _selectedOfferMethod = m);
                            _refreshMerchantAccountsForMethod();
                          },
                        ),
                        if (_selectedMerchantAccount != null) ...[
                          const SizedBox(height: 10),
                          _MerchantAccountCard(
                            c: c,
                            account: _selectedMerchantAccount!,
                          ),
                        ] else if (_offerPaymentMethods.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _InfoChip(c: c, message: 'Payment account details will be shown after trade starts'),
                        ],
                        const SizedBox(height: 18),
                      ],

                      // ── Receiving wallet ───────────────────────────────
                      _SectionLabel(c: c, label: isBuy ? 'Receive ${offer.asset} to' : 'Your wallet (crypto source)'),
                      const SizedBox(height: 8),
                      if (_wallets.isEmpty)
                        _InfoChip(c: c, message: 'No wallet found — add one in your wallet settings', isWarning: true)
                      else
                        _WalletSelector(
                          c: c,
                          wallets: _wallets,
                          selected: _selectedWallet,
                          onChanged: (w) => setState(() => _selectedWallet = w),
                        ),
                      const SizedBox(height: 18),

                      // ── User payment account (optional for buyer) ──────
                      if (_userAccounts.isNotEmpty) ...[
                        _SectionLabel(c: c, label: 'Your payment account (optional)'),
                        const SizedBox(height: 8),
                        _UserAccountSelector(
                          c: c,
                          accounts: _userAccounts,
                          selected: _selectedUserAccount,
                          onChanged: (a) => setState(() => _selectedUserAccount = a),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── Terms notice ───────────────────────────────────
                      _TermsNotice(c: c, offer: offer),
                    ],
                  ),
                ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : _SubmitBar(
              c: c,
              typeColor: typeColor,
              isBuy: isBuy,
              submitting: _submitting,
              onTap: _submit,
            ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: c.primary, strokeWidth: 2.5),
        const SizedBox(height: 14),
        Text('Preparing trade...', style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
      ],
    ),
  );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.c, required this.error, required this.onRetry});
  final AppColor c;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: c.error, size: 32),
          const SizedBox(height: 12),
          Text(
            'Failed to load trade details',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Try again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Offer Summary ─────────────────────────────────────────────────────────────

class _OfferSummaryCard extends StatelessWidget {
  const _OfferSummaryCard({required this.c, required this.offer, required this.typeColor});
  final AppColor c;
  final OfferModel offer;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              offer.type == OfferType.sell
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: typeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${offer.asset} / ${offer.fiatCurrency}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Offer ID: ${offer.id.length > 12 ? '${offer.id.substring(0, 8)}...' : offer.id}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (offer.paymentWindowMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 13, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${offer.paymentWindowMinutes}m',
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
    );
  }
}

// ─── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.c, required this.label});
  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: c.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
      letterSpacing: 0.1,
    ),
  );
}

// ─── Amount field ──────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.c,
    required this.controller,
    required this.currency,
    required this.validator,
    this.min,
    this.max,
  });
  final AppColor c;
  final TextEditingController controller;
  final String currency;
  final String? Function(String?) validator;
  final double? min;
  final double? max;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: TextStyle(
        color: c.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      decoration: InputDecoration(
        prefixText: '$currency ',
        prefixStyle: TextStyle(
          color: c.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        hintText: '0.00',
        hintStyle: TextStyle(color: c.textSecondary.withOpacity(0.4), fontSize: 18),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        helperText: min != null && max != null
            ? 'Min ${min!.toStringAsFixed(2)} · Max ${max!.toStringAsFixed(2)} $currency'
            : null,
        helperStyle: TextStyle(color: c.textSecondary, fontSize: 11.5),
      ),
    );
  }
}

// ─── Crypto equivalent ─────────────────────────────────────────────────────────

class _CryptoEquivalentRow extends StatelessWidget {
  const _CryptoEquivalentRow({
    required this.c,
    required this.asset,
    required this.amount,
    required this.typeColor,
  });
  final AppColor c;
  final String asset;
  final double amount;
  final Color typeColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: typeColor.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: typeColor.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: typeColor),
        const SizedBox(width: 8),
        Text(
          'You receive ≈ ${amount.toStringAsFixed(7)} $asset',
          style: TextStyle(
            color: typeColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

// ─── Payment method selector ───────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.c,
    required this.methods,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selected;
  final ValueChanged<PaymentMethodModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: methods.map((m) {
        final isSelected = selected?.id == m.id;
        final logo = m.logo;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? c.primary.withOpacity(0.06) : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? c.primary.withOpacity(0.4) : c.border.withOpacity(0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (logo != null && logo.isNotEmpty)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: Image.network(logo, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.account_balance_wallet_outlined,
                            size: 20, color: c.textSecondary)),
                  )
                else
                  Icon(Icons.account_balance_wallet_outlined, size: 20, color: c.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: c.primary, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Merchant account card ─────────────────────────────────────────────────────

class _MerchantAccountCard extends StatelessWidget {
  const _MerchantAccountCard({required this.c, required this.account});
  final AppColor c;
  final MerchantPaymentAccountModel account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00C48C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00C48C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.send_rounded, size: 14, color: const Color(0xFF00C48C)),
              const SizedBox(width: 6),
              Text(
                'Send fiat to:',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AccountRow(c: c, label: 'Account name', value: account.accountName),
          if (account.accountNo != null)
            _AccountRow(c: c, label: 'Account no.', value: account.accountNo!),
          if (account.label != null)
            _AccountRow(c: c, label: 'Label', value: account.label!),
          if (account.instructions != null && account.instructions!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              account.instructions!,
              style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.c, required this.label, required this.value});
  final AppColor c;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              showFloatingSnackBar(context, message: 'Copied!', type: SnackBarType.success);
            },
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 13, color: c.textSecondary.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Wallet selector ──────────────────────────────────────────────────────────

class _WalletSelector extends StatelessWidget {
  const _WalletSelector({
    required this.c,
    required this.wallets,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final List<WalletAddress> wallets;
  final WalletAddress? selected;
  final ValueChanged<WalletAddress?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<WalletAddress>(
      value: selected,
      isExpanded: true,
      dropdownColor: c.surface,
      decoration: InputDecoration(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      items: wallets.map((w) {
        final addr = w.publicAddress;
        final short = addr.length > 20
            ? '${addr.substring(0, 10)}...${addr.substring(addr.length - 6)}'
            : addr;
        return DropdownMenuItem(
          value: w,
          child: Text(
            w.label != null ? '${w.label} ($short)' : short,
            style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── User account selector ─────────────────────────────────────────────────────

class _UserAccountSelector extends StatelessWidget {
  const _UserAccountSelector({
    required this.c,
    required this.accounts,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final List<UserPaymentAccountModel> accounts;
  final UserPaymentAccountModel? selected;
  final ValueChanged<UserPaymentAccountModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<UserPaymentAccountModel>(
      value: selected,
      isExpanded: true,
      dropdownColor: c.surface,
      decoration: InputDecoration(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      items: accounts.map((a) => DropdownMenuItem(
        value: a,
        child: Text(
          a.label ?? '${a.accountName}${a.accountNo != null ? ' (${a.accountNo})' : ''}',
          style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.c, required this.message, this.isWarning = false});
  final AppColor c;
  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? c.warning : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ─── Terms notice ─────────────────────────────────────────────────────────────

class _TermsNotice extends StatelessWidget {
  const _TermsNotice({required this.c, required this.offer});
  final AppColor c;
  final OfferModel offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: c.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Trade terms',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TermRow(c: c, text: 'Crypto is held in escrow until payment is confirmed'),
          if (offer.paymentWindowMinutes != null)
            _TermRow(c: c, text: 'You have ${offer.paymentWindowMinutes} minutes to complete payment'),
          _TermRow(c: c, text: 'All disputes are handled through our support system'),
          if (offer.autoReply != null && offer.autoReply!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Merchant note: ${offer.autoReply}',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.c, required this.text});
  final AppColor c;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        Expanded(
          child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4)),
        ),
      ],
    ),
  );
}

// ─── Submit bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.c,
    required this.typeColor,
    required this.isBuy,
    required this.submitting,
    required this.onTap,
  });
  final AppColor c;
  final Color typeColor;
  final bool isBuy;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border.withOpacity(0.15))),
      ),
      child: GestureDetector(
        onTap: submitting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: submitting
                  ? [typeColor.withOpacity(0.5), typeColor.withOpacity(0.4)]
                  : [typeColor, typeColor.withOpacity(0.82)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: submitting
                ? []
                : [
                    BoxShadow(
                      color: typeColor.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isBuy ? 'Start Trade — Buy' : 'Start Trade — Sell',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
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
