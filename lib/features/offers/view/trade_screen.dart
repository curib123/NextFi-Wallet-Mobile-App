import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/merchant_payment_account/merchant_payment_account_core_service.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_dtos.dart';
import 'package:next_fi/services/merchant_payment_account/models/merchant_payment_account_models.dart';
import 'package:next_fi/services/offer_payment_method/models/offer_payment_method_dtos.dart';
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
  const TradeScreen({super.key, required this.offer, this.marketPrice});

  final OfferModel offer;
  final double? marketPrice;

  @override
  State<TradeScreen> createState() => _TradeScreenState(); 
}

class _TradeScreenState extends State<TradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fiatCtrl = TextEditingController();
  final _cryptoCtrl = TextEditingController();
  final _receiverAddressCtrl = TextEditingController();
  final _tradesCore = TradesCoreService.I;
  final _walletCore = WalletCoreService.I;
  final _offerPaymentCore = OfferPaymentMethodCoreService.I;
  final _merchantAccountCore = MerchantPaymentAccountCoreService.I;
  final _userAccountCore = PaymentMethodAndAccountsCoreService.I;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  List<OfferPaymentMethodResponse> _offerPaymentMethods = [];
  List<MerchantPaymentAccountModel> _merchantAccounts = [];
  List<WalletAddress> _wallets = [];
  List<UserPaymentAccountModel> _userAccounts = [];

  OfferPaymentMethodResponse? _selectedOfferMethod;
  MerchantPaymentAccountModel? _selectedMerchantAccount;
  WalletAddress? _selectedWallet;
  UserPaymentAccountModel? _selectedUserAccount;

  bool _enterFiatMode = true;
  double _computedCrypto = 0;
  double _computedFiat = 0;

  OfferModel get offer => widget.offer;

  bool get _userIsBuyer => offer.type == OfferType.sell;
  bool get _receiverIsCurrentActor => _userIsBuyer;

  WalletAddress? get _activeWallet {
    for (final w in _wallets) {
      if (w.isActive && w.publicAddress.trim().isNotEmpty) return w;
    }
    return null;
  }

  String? get _sellerWalletAddress {
    final raw = offer.seller;
    final addr = (offer.receiverStellarAddress ??
            raw?['walletAddress'] ??
            raw?['stellarAddress'] ??
            raw?['receiverStellarAddress'] ??
            raw?['receiver_stellar_address'] ??
            '')
        .toString()
        .trim();
    return addr.isEmpty ? null : addr;
  }

  double get _effectivePrice {
    double? price = (widget.marketPrice != null && widget.marketPrice! > 0)
        ? widget.marketPrice
        : null;
    if (price == null && offer.marketPrice != null && offer.marketPrice! > 0) {
      price = offer.marketPrice;
    }
    if (price != null && price > 0) {
      if (offer.marginPercent != null) {
        return price * (1 + offer.marginPercent! / 100);
      }
      return price;
    }
    return 0.0;
  }

  bool get _canCalculate => _effectivePrice > 0;

  @override
  void initState() {
    super.initState();
    _fiatCtrl.addListener(_onFiatChanged);
    _cryptoCtrl.addListener(_onCryptoChanged);
    _loadData();
  }

  @override
  void dispose() {
    _fiatCtrl.removeListener(_onFiatChanged);
    _cryptoCtrl.removeListener(_onCryptoChanged);
    _fiatCtrl.dispose();
    _cryptoCtrl.dispose();
    _receiverAddressCtrl.dispose();
    super.dispose();
  }

  void _onFiatChanged() {
    final v = double.tryParse(_fiatCtrl.text.trim()) ?? 0;
    if (_effectivePrice > 0) {
      setState(() => _computedCrypto = v / _effectivePrice);
    }
  }

  void _onCryptoChanged() {
    if (_effectivePrice <= 0) return;
    final v = double.tryParse(_cryptoCtrl.text.trim()) ?? 0;
    setState(() => _computedFiat = v * _effectivePrice);
  }

  void _toggleInputMode() {
    setState(() {
      _enterFiatMode = !_enterFiatMode;
      if (_enterFiatMode) {
        _cryptoCtrl.clear();
        _computedFiat = 0;
      } else {
        _fiatCtrl.clear();
        _computedCrypto = 0;
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _offerPaymentCore.getOfferPaymentMethodsWithId(offer.id),
        _walletCore.list(),
        _userAccountCore.listMyPaymentAccounts(activeOnly: true),
        _loadMerchantAccounts(),
      ]);

      if (!mounted) return;

      setState(() {
        _offerPaymentMethods = results[0] as List<OfferPaymentMethodResponse>;
        _wallets = (results[1] as List<WalletAddress>)
            .where((w) => w.publicAddress.trim().isNotEmpty)
            .toList();
        _userAccounts = results[2] as List<UserPaymentAccountModel>;
        _merchantAccounts = results[3] as List<MerchantPaymentAccountModel>;

        if (_wallets.isNotEmpty) {
          _selectedWallet = _wallets.firstWhere(
                (w) => w.isActive,
            orElse: () => _wallets.first,
          );
        }
        if (_offerPaymentMethods.isNotEmpty) {
          _selectedOfferMethod = _offerPaymentMethods.first;
        }
        if (!_userIsBuyer && _userAccounts.isNotEmpty) {
          _selectedUserAccount = _userAccounts.first;
        }
        _loading = false;
      });

      _refreshMerchantAccountsForMethod();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
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
    } catch (e) {
      return [];
    }
  }

  void _refreshMerchantAccountsForMethod() {
    if (_selectedOfferMethod == null) {
      setState(() => _selectedMerchantAccount = null);
      return;
    }
    final methodId = _selectedOfferMethod!.paymentMethodId;
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
    if (min != null && parsed < min) return 'Minimum is ${offer.fiatCurrency} $min';
    if (max != null && parsed > max) return 'Maximum is ${offer.fiatCurrency} $max';
    return null;
  }

  String? _validateCrypto(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return 'Invalid amount';
    if (_effectivePrice > 0) {
      final fiat = parsed * _effectivePrice;
      final min = offer.minAmount;
      final max = offer.maxAmount;
      if (min != null && fiat < min) {
        return 'Below minimum ${offer.fiatCurrency} ${min.toStringAsFixed(2)}';
      }
      if (max != null && fiat > max) {
        return 'Above maximum ${offer.fiatCurrency} ${max.toStringAsFixed(2)}';
      }
    }
    if (offer.availableQty != null && parsed > offer.availableQty!) {
      return 'Maximum available is ${offer.availableQty} ${offer.asset}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_userIsBuyer && _selectedWallet == null) {
      showFloatingSnackBar(
        context,
        message: 'No wallet address found. Please add a wallet first.',
        type: SnackBarType.error,
      );
      return;
    }

    final fiatAmount = _enterFiatMode
        ? _fiatCtrl.text.trim()
        : _computedFiat.toStringAsFixed(2);
    final cryptoAmount = _enterFiatMode
        ? _computedCrypto.toStringAsFixed(7)
        : _cryptoCtrl.text.trim();

    final fiatParsed = double.tryParse(fiatAmount);
    final cryptoParsed = double.tryParse(cryptoAmount);

    if (fiatParsed == null || fiatParsed <= 0) {
      showFloatingSnackBar(context, message: 'Please enter a valid fiat amount.', type: SnackBarType.error);
      return;
    }
    if (cryptoParsed == null || cryptoParsed <= 0) {
      showFloatingSnackBar(context, message: 'Could not calculate crypto amount. Please try again.', type: SnackBarType.error);
      return;
    }
    if (_selectedOfferMethod == null) {
      showFloatingSnackBar(context, message: 'Please select a payment method.', type: SnackBarType.error);
      return;
    }
    if (_userIsBuyer && _selectedMerchantAccount == null) {
      showFloatingSnackBar(
        context,
        message:
            'Seller payment account is unavailable for this method. Choose another method/offer.',
        type: SnackBarType.error,
      );
      return;
    }
    if (!_userIsBuyer && _selectedUserAccount == null) {
      showFloatingSnackBar(context, message: 'Please select your receiving payment account.', type: SnackBarType.error);
      return;
    }

    String cryptoReceiverAddress = '';
    if (_receiverIsCurrentActor) {
      final activeAddress = _activeWallet?.publicAddress.trim() ?? '';
      if (activeAddress.isEmpty) {
        showFloatingSnackBar(
          context,
          message: 'Active wallet address is missing. Please set an active wallet first.',
          type: SnackBarType.error,
        );
        return;
      }
      cryptoReceiverAddress = activeAddress;
    } else {
      final sellerReceiverAddress = _sellerWalletAddress;
      if (sellerReceiverAddress != null && sellerReceiverAddress.isNotEmpty) {
        cryptoReceiverAddress = sellerReceiverAddress;
      } else {
        final manual = _receiverAddressCtrl.text.trim();
        if (manual.isEmpty) {
          showFloatingSnackBar(
            context,
            message: 'Receiver address (where funds will be sent) is required.',
            type: SnackBarType.error,
          );
          return;
        }
        if (!RegExp(r'^G[A-Z2-7]{55}$').hasMatch(manual)) {
          showFloatingSnackBar(
            context,
            message: 'Receiver address format is invalid.',
            type: SnackBarType.error,
          );
          return;
        }
        cryptoReceiverAddress = manual;
      }
    }

    if (cryptoReceiverAddress.trim().isEmpty) {
      showFloatingSnackBar(context, message: 'Crypto receiver address is missing.', type: SnackBarType.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      final trade = await _tradesCore.create(
        CreateTradeRequest(
          offerId: offer.id,
          paymentMethodId: _selectedOfferMethod!.paymentMethodId,
          buyerPaymentAccountId: _userIsBuyer ? null : _selectedUserAccount?.id,
          cryptoAmount: cryptoAmount,
          fiatAmount: fiatAmount,
          cryptoReceiverAddress: cryptoReceiverAddress, 
        ),
      ); 
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TradeOrderScreen(trade: trade, offer: offer),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('TradeApiException')) {
        msg = msg.replaceAll(RegExp(r'TradeApiException\(\d+\): '), '');
      }
      showFloatingSnackBar(context, message: msg, type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isBuy = _userIsBuyer;
    final typeColor = isBuy ? c.success : c.error;
    final effectivePrice = _effectivePrice;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: c.surface,
        shadowColor: c.surface,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          isBuy ? 'Buy ${offer.asset}' : 'Sell ${offer.asset}',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.55,
          ),
        ),
      ),
      body: _loading
          ? const _LoadingBody()
          : _loadError != null
          ? _ErrorBody(c: c, error: _loadError!, onRetry: _loadData)
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
          children: [
            _OfferSummaryCard(c: c, offer: offer, typeColor: typeColor),
            const SizedBox(height: 10),
            _PriceInsightsCard(
              c: c,
              offer: offer,
              typeColor: typeColor,
              effectivePrice: effectivePrice,
            ),
            const SizedBox(height: 16),

            // ── Amount input ───────────────────────────────
            _PanelCard(
              c: c,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    c: c,
                    label: _enterFiatMode
                        ? (isBuy ? 'You pay (fiat)' : 'You receive (fiat)')
                        : (isBuy
                        ? 'You receive (${offer.asset})'
                        : 'You send (${offer.asset})'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AmountField(
                          c: c,
                          controller: _enterFiatMode ? _fiatCtrl : _cryptoCtrl,
                          currency: _enterFiatMode ? offer.fiatCurrency : offer.asset,
                          validator: _enterFiatMode ? _validateFiat : _validateCrypto,
                          min: _enterFiatMode ? offer.minAmount : null,
                          max: _enterFiatMode ? offer.maxAmount : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ModeToggleButton(c: c, onTap: _toggleInputMode),
                    ],
                  ),
                  if (_enterFiatMode && _computedCrypto > 0) ...[
                    const SizedBox(height: 8),
                    _CryptoEquivalentRow(
                      c: c,
                      asset: offer.asset,
                      amount: _computedCrypto,
                      typeColor: typeColor,
                      isBuy: isBuy,
                    ),
                  ],
                  if (!_enterFiatMode && _computedFiat > 0) ...[
                    const SizedBox(height: 8),
                    _FiatEquivalentRow(
                      c: c,
                      currency: offer.fiatCurrency,
                      amount: _computedFiat,
                      typeColor: typeColor,
                      isBuy: isBuy,
                    ),
                  ],
                  if (_enterFiatMode && !_canCalculate) ...[
                    const SizedBox(height: 8),
                    _InfoChip(
                      c: c,
                      message: 'No market price available. Toggle to enter crypto amount directly.',
                      isWarning: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isBuy && _offerPaymentMethods.isNotEmpty) ...[
              _PanelCard(
                c: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(c: c, label: 'Pay via'),
                    const SizedBox(height: 10),
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
                      const SizedBox(height: 12),
                      _MerchantAccountCard(c: c, account: _selectedMerchantAccount!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _PanelCard(
              c: c,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(c: c, label: 'Receiver address'),
                  const SizedBox(height: 10),
                  if (_receiverIsCurrentActor)
                    _ReadOnlyAddressTile(
                      c: c,
                      label: 'Receiving to',
                      address: _activeWallet?.publicAddress.trim(),
                    )
                  else if ((_sellerWalletAddress ?? '').isNotEmpty)
                    _ReadOnlyAddressTile(
                      c: c,
                      label: 'Receiving to',
                      address: _sellerWalletAddress,
                    )
                  else
                    TextFormField(
                      controller: _receiverAddressCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      ],
                      validator: (v) {
                        if (!_receiverIsCurrentActor && (_sellerWalletAddress ?? '').isEmpty) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) {
                            return 'Receiver address (where funds will be sent) is required';
                          }
                          if (!RegExp(r'^G[A-Z2-7]{55}$').hasMatch(value)) {
                            return 'Invalid Stellar address';
                          }
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Receiver address (where funds will be sent)',
                        hintText: 'G...',
                        filled: true,
                        fillColor: c.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.primary, width: 1.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!isBuy) ...[
              _PanelCard(
                c: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(c: c, label: 'Your wallet (crypto source)'),
                    const SizedBox(height: 10),
                    if (_wallets.isEmpty)
                    _InfoChip(
                      c: c,
                      message: 'No wallet found - add one in your wallet settings',
                      isWarning: true,
                    )
                    else
                      _WalletSelector(
                        c: c,
                        wallets: _wallets,
                        selected: _selectedWallet,
                        onChanged: (w) => setState(() => _selectedWallet = w),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_userAccounts.isNotEmpty && !isBuy) ...[
              _PanelCard(
                c: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(c: c, label: 'Your payment account (for receiving fiat)'),
                    const SizedBox(height: 10),
                    _UserAccountSelector(
                      c: c,
                      accounts: _userAccounts,
                      selected: _selectedUserAccount,
                      onChanged: (a) => setState(() => _selectedUserAccount = a),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _PanelCard(c: c, child: _TermsNotice(c: c, offer: offer)),
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
        disabled: _enterFiatMode && !_canCalculate,
        onTap: _submit,
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _ReadOnlyAddressTile extends StatelessWidget {
  const _ReadOnlyAddressTile({
    required this.c,
    required this.label,
    required this.address,
  });

  final AppColor c;
  final String label;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final value = (address ?? '').trim();
    if (value.isEmpty) {
      return _InfoChip(
        c: c,
        message: 'Receiver address is unavailable.',
        isWarning: true,
      );
    }

    final short = value.length > 14
        ? '${value.substring(0, 6)}...${value.substring(value.length - 6)}'
        : value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Text(
        '$label: $short',
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) =>
      const PageLoader(label: 'Preparing trade...');
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
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
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
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Try again',
                style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Panel Card ───────────────────────────────────────────────────────────────

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.c, required this.child});
  final AppColor c;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.border),
    ),
    child: child,
  );
}

// ─── Mode Toggle Button ───────────────────────────────────────────────────────

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({required this.c, required this.onTap});
  final AppColor c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Icon(Icons.swap_horiz_rounded, color: c.primary, size: 24),
    ),
  );
}

// ─── Price Insights Card ──────────────────────────────────────────────────────

class _PriceInsightsCard extends StatelessWidget {
  const _PriceInsightsCard({
    required this.c,
    required this.offer,
    required this.typeColor,
    required this.effectivePrice,
  });
  final AppColor c;
  final OfferModel offer;
  final Color typeColor;
  final double effectivePrice;

  @override
  Widget build(BuildContext context) {
    final market = offer.marketPrice;
    final hasPrice = effectivePrice > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PriceMetric(
              c: c,
              label: 'Market',
              value: market != null && market > 0
                  ? '${offer.fiatCurrency} ${market.toStringAsFixed(2)}'
                  : 'Not available',
            ),
          ),
          Container(width: 1, height: 26, color: c.border),
          Expanded(
            child: _PriceMetric(
              c: c,
              label: 'Effective',
              value: hasPrice
                  ? '${offer.fiatCurrency} ${effectivePrice.toStringAsFixed(2)}'
                  : 'Unavailable',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceMetric extends StatelessWidget {
  const _PriceMetric({
    required this.c,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });
  final AppColor c;
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 10.5,
          letterSpacing: 0.45,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 13.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );
}

// ─── Offer Summary Card ───────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 17.5,
                    letterSpacing: -0.45,
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
          if (offer.paymentWindowMinutes != null || offer.successRate != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (offer.paymentWindowMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
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
                if (offer.successRate != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: c.success),
                        const SizedBox(width: 4),
                        Text(
                          '${offer.successRate!.toStringAsFixed(1)}%',
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
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.c, required this.label});
  final AppColor c;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: c.textPrimary,
      fontWeight: FontWeight.w800,
      fontSize: 13.2,
      letterSpacing: -0.1,
    ),
  );
}

// ─── Amount Field ─────────────────────────────────────────────────────────────

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
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,7}')),
      ],
      style: TextStyle(
        color: c.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 19,
      ),
      decoration: InputDecoration(
        prefixText: '$currency ',
        prefixStyle: TextStyle(
          color: c.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        hintText: '0.00',
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 19),
        filled: true,
        fillColor: c.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
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

// ─── Crypto Equivalent Row ────────────────────────────────────────────────────

class _CryptoEquivalentRow extends StatelessWidget {
  const _CryptoEquivalentRow({
    required this.c,
    required this.asset,
    required this.amount,
    required this.typeColor,
    required this.isBuy,
  });
  final AppColor c;
  final String asset;
  final double amount;
  final Color typeColor;
  final bool isBuy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.border),
    ),
    child: Row(
      children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: typeColor),
        const SizedBox(width: 8),
        Text(
          isBuy
              ? 'You receive ≈ ${amount.toStringAsFixed(7)} $asset'
              : 'You send ≈ ${amount.toStringAsFixed(7)} $asset',
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

// ─── Fiat Equivalent Row ──────────────────────────────────────────────────────

class _FiatEquivalentRow extends StatelessWidget {
  const _FiatEquivalentRow({
    required this.c,
    required this.currency,
    required this.amount,
    required this.typeColor,
    required this.isBuy,
  });
  final AppColor c;
  final String currency;
  final double amount;
  final Color typeColor;
  final bool isBuy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: c.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.border),
    ),
    child: Row(
      children: [
        Icon(Icons.swap_horiz_rounded, size: 16, color: typeColor),
        const SizedBox(width: 8),
        Text(
          isBuy
              ? 'You pay ≈ $currency ${amount.toStringAsFixed(2)}'
              : 'You receive ≈ $currency ${amount.toStringAsFixed(2)}',
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

// ─── Payment Method Selector ──────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.c,
    required this.methods,
    required this.selected,
    required this.onChanged,
  });
  final AppColor c;
  final List<OfferPaymentMethodResponse> methods;
  final OfferPaymentMethodResponse? selected;
  final ValueChanged<OfferPaymentMethodResponse?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: methods.map((m) {
        final isSelected = selected?.id == m.id;
        final logo = m.paymentMethod.logo;
        return GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? c.primary : c.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? c.primary : c.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (logo != null && logo.isNotEmpty)
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: Image.network(
                      logo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: isSelected ? c.onPrimary : c.textSecondary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: isSelected ? c.onPrimary : c.textSecondary,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.paymentMethod.name,
                    style: TextStyle(
                      color: isSelected ? c.onPrimary : c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.2,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: c.onPrimary, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Merchant Account Card ────────────────────────────────────────────────────

class _MerchantAccountCard extends StatelessWidget {
  const _MerchantAccountCard({required this.c, required this.account});
  final AppColor c;
  final MerchantPaymentAccountModel account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.send_rounded, size: 14, color: c.success),
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
                Icon(Icons.copy_rounded, size: 13, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Wallet Selector ──────────────────────────────────────────────────────────

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      items: wallets.map((w) {
        final addr = w.publicAddress;
        final short = addr.length > 20
            ? '${addr.substring(0, 10)}...${addr.substring(addr.length - 6)}'
            : addr;
        final label = (w.label ?? '').trim();
        return DropdownMenuItem(
          value: w,
          child: Text(
            label.isNotEmpty ? '$label ($short)' : short,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── User Account Selector ────────────────────────────────────────────────────

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      items: accounts.map((a) {
        final label = (a.label ?? '').trim();
        final accountName = a.accountName.trim();
        final accountNo = (a.accountNo ?? '').trim();
        final fallbackName = accountName.isNotEmpty ? accountName : 'Saved account';
        final display = label.isNotEmpty
            ? label
            : '$fallbackName${accountNo.isNotEmpty ? ' ($accountNo)' : ''}';
        return DropdownMenuItem(
          value: a,
          child: Text(
            display,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.c, required this.message, this.isWarning = false});
  final AppColor c;
  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? c.warning : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? c.warning : c.border),
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

// ─── Terms Notice ─────────────────────────────────────────────────────────────

class _TermsNotice extends StatelessWidget {
  const _TermsNotice({required this.c, required this.offer});
  final AppColor c;
  final OfferModel offer;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: Text(
            text,
            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

// ─── Submit Bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.c,
    required this.typeColor,
    required this.isBuy,
    required this.submitting,
    required this.disabled,
    this.onTap,
  });
  final AppColor c;
  final Color typeColor;
  final bool isBuy;
  final bool submitting;
  final bool disabled;
  final VoidCallback? onTap;

  bool get _isDisabled => disabled || submitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: GestureDetector(
        onTap: _isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            color: _isDisabled
                ? c.border
                : submitting
                ? typeColor
                : typeColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: submitting
                ? SizedBox(
              width: 24,
              height: 24,
              child: ModernFintechLoader(color: c.onPrimary, size: 24),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: c.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  disabled
                      ? 'Toggle to enter amount'
                      : (isBuy ? 'Start Trade — Buy' : 'Start Trade — Sell'),
                  style: TextStyle(
                    color: c.onPrimary,
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
