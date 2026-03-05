import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/offers/view/trade_order_screen.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/offers/models/offers_models.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/trade_payment_accounts/models/trade_payment_accounts_models.dart';
import 'package:next_fi/services/trade_payment_accounts/trade_payment_accounts_core_service.dart';
import 'package:next_fi/services/trades/models/trades_dtos.dart';
import 'package:next_fi/services/trades/trades_core_service.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';
import 'package:next_fi/services/payment_method_and_accounts/payment_method_and_accounts_core_service.dart';
import 'package:next_fi/services/payment_method_and_accounts/models/payment_method_and_accounts_models.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, required this.offer, this.marketPrice});

  final OfferModel offer;
  final double? marketPrice;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fiatCtrl = TextEditingController();
  final _cryptoCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  final _tradesCore = TradesCoreService.I;
  final _tradePaymentCore = TradePaymentAccountsCoreService.I;
  final _userAccountCore = PaymentMethodAndAccountsCoreService.I;

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  List<PaymentMethodModel> _offerPaymentMethods = [];
  List<UserPaymentAccountModel> _merchantAccounts = [];
  List<UserPaymentAccountModel> _userAccounts = [];
  String? _activeWalletAddress;

  PaymentMethodModel? _selectedOfferMethod;
  UserPaymentAccountModel? _selectedMerchantAccount;
  UserPaymentAccountModel? _selectedUserAccount;

  bool _enterFiatMode = true;
  double _computedCrypto = 0;
  double _computedFiat = 0;

  OfferModel get offer => widget.offer;

  bool get _userIsBuyer => offer.type == OfferType.sell;
  bool get _receiverIsCurrentActor => _userIsBuyer;
  static final RegExp _stellarAddressRegExp = RegExp(r'^G[A-Z2-7]{55}$');

  String _normalizeId(String? value) => value?.trim().toLowerCase() ?? '';
  String _selectedMethodId() => _normalizeId(_selectedOfferMethod?.id);

  List<UserPaymentAccountModel> get _filteredUserAccounts {
    final methodId = _selectedMethodId();
    if (methodId.isEmpty) return _userAccounts;
    return _userAccounts.where((a) {
      final accountMethodId = _normalizeId(a.paymentMethodId);
      return accountMethodId.isNotEmpty && accountMethodId == methodId;
    }).toList();
  }

  List<UserPaymentAccountModel> get _filteredMerchantAccounts {
    final methodId = _selectedMethodId();
    if (methodId.isEmpty) return _merchantAccounts;
    return _merchantAccounts.where((a) {
      final accountMethodId = _normalizeId(a.paymentMethodId);
      return accountMethodId.isNotEmpty && accountMethodId == methodId;
    }).toList();
  }

  String? get _submitBlockedReason {
    if (_enterFiatMode && !_canCalculate) return 'Toggle to crypto input';
    if (_selectedOfferMethod == null) return 'Select payment method';
    if (_filteredUserAccounts.isEmpty) return 'Add account for selected method';
    if (_selectedUserAccount == null) return 'Select your account';
    final receiver = _receiverAddressForTradeRoom?.trim() ?? '';
    if (receiver.isEmpty) return 'Enter receiver address';
    if (!_stellarAddressRegExp.hasMatch(receiver)) return 'Invalid receiver address';
    return null;
  }

  String? get _defaultReceiverAddress {
    // User is selling crypto (BUY offer): prefer the selected payment account
    // settlement address configured in User Payment Accounts.
    if (!_userIsBuyer) {
      final fromAccount =
          _selectedUserAccount?.assetReceiverAddress?.trim() ?? '';
      if (fromAccount.isNotEmpty) return fromAccount;
    }
    final active = _activeWalletAddress?.trim() ?? '';
    if (active.isNotEmpty) return active;
    return null;
  }

  String? get _receiverAddressForTradeRoom {
    final typed = _receiverCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return _defaultReceiverAddress;
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fiatCtrl.addListener(_onFiatChanged);
    _cryptoCtrl.addListener(_onCryptoChanged);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _fiatCtrl.removeListener(_onFiatChanged);
    _cryptoCtrl.removeListener(_onCryptoChanged);
    _fiatCtrl.dispose();
    _cryptoCtrl.dispose();
    _receiverCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<String?> _resolveActiveWalletAddress() async {
    try {
      final managerAddress = await WalletManager.I.getActiveWalletAddress();
      final trimmed = managerAddress?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    } catch (_) {}
    final localActive = await SeedStorage.getActiveWalletMeta();
    final localAddress = localActive?.publicAddress?.trim() ?? '';
    return localAddress.isEmpty ? null : localAddress;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      TradePaymentAccountsContext? tradeContext;
      try {
        tradeContext = await _tradePaymentCore.getOfferContext(
          offer.id,
          activeOnly: true,
        );
      } catch (_) {
        tradeContext = null;
      }

      final results = await Future.wait([
        _userAccountCore.listMyPaymentAccounts(activeOnly: true),
        _userAccountCore.listPaymentMethods(activeOnly: true),
      ]);
      final activeWalletAddress = await _resolveActiveWalletAddress();
      final fallbackAccounts = results[0] as List<UserPaymentAccountModel>;
      final allMethods = results[1] as List<PaymentMethodModel>;

      if (!mounted) return;

      final offeredIds = offer.paymentMethodIds
          .map(_normalizeId)
          .where((e) => e.isNotEmpty)
          .toSet();
      final contextMethods =
          tradeContext?.paymentMethods ?? const <PaymentMethodModel>[];
      final methods =
      (contextMethods.isNotEmpty ? contextMethods : allMethods)
          .where((m) =>
      offeredIds.isEmpty ||
          offeredIds.contains(_normalizeId(m.id)))
          .toList();

      setState(() {
        _offerPaymentMethods = methods;
        _merchantAccounts = tradeContext?.merchantAccounts ?? const [];
        _userAccounts = tradeContext?.clientAccounts.isNotEmpty == true
            ? tradeContext!.clientAccounts
            : fallbackAccounts;
        _activeWalletAddress = activeWalletAddress;
        if (_offerPaymentMethods.isNotEmpty) {
          _selectedOfferMethod = _offerPaymentMethods.first;
        }
        _loading = false;
      });
      if (_receiverCtrl.text.trim().isEmpty) {
        final initialReceiver = _defaultReceiverAddress;
        if (initialReceiver != null && initialReceiver.isNotEmpty) {
          _receiverCtrl.text = initialReceiver;
        }
      }
      _refreshMerchantAccountsForMethod();
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _refreshMerchantAccountsForMethod() {
    if (_selectedOfferMethod == null) {
      setState(() {
        _selectedMerchantAccount = null;
        _selectedUserAccount = null;
      });
      return;
    }
    final filteredMerchant = _filteredMerchantAccounts;
    final filteredUser = _filteredUserAccounts;
    setState(() {
      _selectedMerchantAccount =
      filteredMerchant.isEmpty ? null : filteredMerchant.first;
      if (filteredUser.isEmpty) {
        _selectedUserAccount = null;
      } else if (_selectedUserAccount == null ||
          _normalizeId(_selectedUserAccount!.paymentMethodId) !=
              _selectedMethodId()) {
        _selectedUserAccount = filteredUser.first;
      }
      final resolved = _defaultReceiverAddress ?? '';
      _receiverCtrl.text = resolved;
    });
  }

  // ── Input handlers ─────────────────────────────────────────────────────────

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
    HapticFeedback.lightImpact();
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

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateFiat(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return 'Invalid amount';
    final min = offer.minAmount;
    final max = offer.maxAmount;
    if (min != null && parsed < min) return 'Min is ${offer.fiatCurrency} $min';
    if (max != null && parsed > max) return 'Max is ${offer.fiatCurrency} $max';
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
        return 'Below min ${offer.fiatCurrency} ${min.toStringAsFixed(2)}';
      }
      if (max != null && fiat > max) {
        return 'Above max ${offer.fiatCurrency} ${max.toStringAsFixed(2)}';
      }
    }
    if (offer.availableQty != null && parsed > offer.availableQty!) {
      return 'Max available: ${offer.availableQty} ${offer.asset}';
    }
    return null;
  }

  String? _validateReceiverAddress(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Enter receiver address';
    if (!_stellarAddressRegExp.hasMatch(value)) {
      return 'Invalid Stellar address';
    }
    return null;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final fiatAmount = _enterFiatMode
        ? _fiatCtrl.text.trim()
        : _computedFiat.toStringAsFixed(2);
    final cryptoAmount = _enterFiatMode
        ? _computedCrypto.toStringAsFixed(7)
        : _cryptoCtrl.text.trim();

    final fiatParsed = double.tryParse(fiatAmount);
    final cryptoParsed = double.tryParse(cryptoAmount);

    if (fiatParsed == null || fiatParsed <= 0) {
      showFloatingSnackBar(context,
          message: 'Please enter a valid fiat amount.',
          type: SnackBarType.error);
      return;
    }
    if (cryptoParsed == null || cryptoParsed <= 0) {
      showFloatingSnackBar(context,
          message: 'Could not calculate crypto amount. Please try again.',
          type: SnackBarType.error);
      return;
    }
    if (_selectedOfferMethod == null) {
      showFloatingSnackBar(context,
          message: 'Please select a payment method.', type: SnackBarType.error);
      return;
    }
    if (_selectedUserAccount == null) {
      showFloatingSnackBar(context,
          message: 'Please select your payment account.',
          type: SnackBarType.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      final trade = await _tradesCore.create(
        CreateTradeRequest(
          offerId: offer.id,
          userPaymentAccountId: _selectedUserAccount!.id,
          cryptoAmount: cryptoAmount,
          fiatAmount: fiatAmount,
          cryptoReceiverAddress: _receiverAddressForTradeRoom,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TradeOrderScreen(
            trade: trade,
            offer: offer,
            receiverAddressOverride: _receiverAddressForTradeRoom,
          ),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isBuy = _userIsBuyer;
    final typeColor = isBuy ? c.success : c.error;

    return Scaffold(
      backgroundColor: c.background,
      appBar: _buildAppBar(c, isBuy, typeColor),
      body: _loading
          ? const PageLoader(label: 'Preparing trade...')
          : _loadError != null
          ? _ErrorBody(c: c, error: _loadError!, onRetry: _loadData)
          : FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              // ── Hero price banner ──────────────────────────────
              _HeroBanner(
                c: c,
                offer: offer,
                effectivePrice: _effectivePrice,
                canCalculate: _canCalculate,
                typeColor: typeColor,
                isBuy: isBuy,
              ),
              const SizedBox(height: 12),

              // ── Amount card ────────────────────────────────────
              _AmountCard(
                c: c,
                offer: offer,
                enterFiatMode: _enterFiatMode,
                fiatCtrl: _fiatCtrl,
                cryptoCtrl: _cryptoCtrl,
                computedCrypto: _computedCrypto,
                computedFiat: _computedFiat,
                canCalculate: _canCalculate,
                typeColor: typeColor,
                isBuy: isBuy,
                onToggle: _toggleInputMode,
                fiatValidator: _validateFiat,
                cryptoValidator: _validateCrypto,
              ),
              const SizedBox(height: 12),

              // ── Payment method card ────────────────────────────
              if (_offerPaymentMethods.isNotEmpty)
                _PaymentMethodCard(
                  c: c,
                  methods: _offerPaymentMethods,
                  selected: _selectedOfferMethod,
                  merchantAccount: isBuy ? _selectedMerchantAccount : null,
                  isBuy: isBuy,
                  onChanged: (m) {
                    setState(() => _selectedOfferMethod = m);
                    _refreshMerchantAccountsForMethod();
                  },
                )
              else
                _WarnCard(
                  c: c,
                  message:
                  'This offer has no active payment method. Choose another offer.',
                ),
              const SizedBox(height: 12),

              // ── Receiver address card ──────────────────────────
              _ReceiverCard(
                c: c,
                receiverIsCurrentActor: _receiverIsCurrentActor,
                receiverController: _receiverCtrl,
                validator: _validateReceiverAddress,
                defaultAddress: _defaultReceiverAddress,
              ),
              const SizedBox(height: 12),

              // ── Your account card ──────────────────────────────
              _YourAccountCard(
                c: c,
                accounts: _filteredUserAccounts,
                selected: _selectedUserAccount,
                onChanged: (a) => setState(() {
                  _selectedUserAccount = a;
                  _receiverCtrl.text = _defaultReceiverAddress ?? '';
                }),
              ),
              const SizedBox(height: 12),

              // ── Terms card ────────────────────────────────────
              _TermsCard(c: c, offer: offer),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : _SubmitBar(
        c: c,
        typeColor: typeColor,
        isBuy: isBuy,
        asset: offer.asset,
        submitting: _submitting,
        disabled: _submitBlockedReason != null,
        disabledLabel: _submitBlockedReason,
        onTap: _submit,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AppColor c, bool isBuy, Color typeColor) {
    return AppBar(
      backgroundColor: c.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: c.textPrimary, size: 15),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBuy
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: typeColor,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  isBuy ? 'BUY' : 'SELL',
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            offer.asset,
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            ' / ${offer.fiatCurrency}',
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.c,
    required this.offer,
    required this.effectivePrice,
    required this.canCalculate,
    required this.typeColor,
    required this.isBuy,
  });

  final AppColor c;
  final OfferModel offer;
  final double effectivePrice;
  final bool canCalculate;
  final Color typeColor;
  final bool isBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Left: price info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                canCalculate
                    ? Text(
                  '${offer.fiatCurrency} ${effectivePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -0.7,
                  ),
                )
                    : Text(
                  'Price unavailable',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (offer.marginPercent != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${offer.marginPercent! >= 0 ? '+' : ''}${offer.marginPercent!.toStringAsFixed(1)}% margin',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right: badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (offer.paymentWindowMinutes != null)
                _StatBadge(
                  c: c,
                  icon: Icons.timer_outlined,
                  label: '${offer.paymentWindowMinutes}m window',
                ),
              if (offer.successRate != null) ...[
                const SizedBox(height: 6),
                _StatBadge(
                  c: c,
                  icon: Icons.verified_rounded,
                  label:
                  '${offer.successRate!.toStringAsFixed(0)}% success',
                  iconColor: c.success,
                ),
              ],
              if (offer.minAmount != null || offer.maxAmount != null) ...[
                const SizedBox(height: 6),
                _StatBadge(
                  c: c,
                  icon: Icons.swap_vert_rounded,
                  label: offer.minAmount != null && offer.maxAmount != null
                      ? '${offer.fiatCurrency} ${_fmt(offer.minAmount!)}–${_fmt(offer.maxAmount!)}'
                      : offer.maxAmount != null
                      ? 'Max ${offer.fiatCurrency} ${_fmt(offer.maxAmount!)}'
                      : 'Min ${offer.fiatCurrency} ${_fmt(offer.minAmount!)}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.c,
    required this.icon,
    required this.label,
    this.iconColor,
  });
  final AppColor c;
  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? c.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Amount Card ──────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.c,
    required this.offer,
    required this.enterFiatMode,
    required this.fiatCtrl,
    required this.cryptoCtrl,
    required this.computedCrypto,
    required this.computedFiat,
    required this.canCalculate,
    required this.typeColor,
    required this.isBuy,
    required this.onToggle,
    required this.fiatValidator,
    required this.cryptoValidator,
  });

  final AppColor c;
  final OfferModel offer;
  final bool enterFiatMode;
  final TextEditingController fiatCtrl;
  final TextEditingController cryptoCtrl;
  final double computedCrypto;
  final double computedFiat;
  final bool canCalculate;
  final Color typeColor;
  final bool isBuy;
  final VoidCallback onToggle;
  final FormFieldValidator<String> fiatValidator;
  final FormFieldValidator<String> cryptoValidator;

  @override
  Widget build(BuildContext context) {
    final inputLabel = enterFiatMode
        ? (isBuy ? 'You pay' : 'You receive')
        : (isBuy ? 'You receive' : 'You send');
    final currency = enterFiatMode ? offer.fiatCurrency : offer.asset;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inputLabel,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              _TogglePill(
                c: c,
                enterFiatMode: enterFiatMode,
                fiatCurrency: offer.fiatCurrency,
                asset: offer.asset,
                onTap: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Input field
          TextFormField(
            controller: enterFiatMode ? fiatCtrl : cryptoCtrl,
            validator: enterFiatMode ? fiatValidator : cryptoValidator,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,7}')),
            ],
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: -0.8,
            ),
            decoration: InputDecoration(
              prefixText: '$currency ',
              prefixStyle: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                color: c.textSecondary.withOpacity(0.4),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
              filled: true,
              fillColor: c.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
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
                borderSide: BorderSide(color: typeColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: c.error, width: 1.5),
              ),
            ),
          ),

          // Min/max hint
          if (offer.minAmount != null && offer.maxAmount != null &&
              enterFiatMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: c.textSecondary),
                const SizedBox(width: 5),
                Text(
                  'Limits: ${offer.fiatCurrency} ${offer.minAmount!.toStringAsFixed(0)} – ${offer.maxAmount!.toStringAsFixed(0)}',
                  style:
                  TextStyle(color: c.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ],

          // Conversion result
          if (enterFiatMode && computedCrypto > 0) ...[
            const SizedBox(height: 12),
            _ConversionRow(
              c: c,
              typeColor: typeColor,
              label: isBuy ? 'You receive' : 'You send',
              value:
              '≈ ${computedCrypto.toStringAsFixed(7)} ${offer.asset}',
            ),
          ],
          if (!enterFiatMode && computedFiat > 0) ...[
            const SizedBox(height: 12),
            _ConversionRow(
              c: c,
              typeColor: typeColor,
              label: isBuy ? 'You pay' : 'You receive',
              value:
              '≈ ${offer.fiatCurrency} ${computedFiat.toStringAsFixed(2)}',
            ),
          ],
          if (enterFiatMode && !canCalculate) ...[
            const SizedBox(height: 12),
            _InlineWarn(
              c: c,
              message:
              'No market price. Toggle to enter ${offer.asset} directly.',
            ),
          ],
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.c,
    required this.enterFiatMode,
    required this.fiatCurrency,
    required this.asset,
    required this.onTap,
  });

  final AppColor c;
  final bool enterFiatMode;
  final String fiatCurrency;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enterFiatMode ? fiatCurrency : asset,
              style: TextStyle(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.swap_horiz_rounded, color: c.primary, size: 16),
            const SizedBox(width: 5),
            Text(
              enterFiatMode ? asset : fiatCurrency,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversionRow extends StatelessWidget {
  const _ConversionRow({
    required this.c,
    required this.typeColor,
    required this.label,
    required this.value,
  });

  final AppColor c;
  final Color typeColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.compare_arrows_rounded, size: 15, color: typeColor),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: TextStyle(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: typeColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Method Card ───────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.c,
    required this.methods,
    required this.selected,
    required this.merchantAccount,
    required this.isBuy,
    required this.onChanged,
  });

  final AppColor c;
  final List<PaymentMethodModel> methods;
  final PaymentMethodModel? selected;
  final UserPaymentAccountModel? merchantAccount;
  final bool isBuy;
  final ValueChanged<PaymentMethodModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            c: c,
            icon: Icons.account_balance_wallet_outlined,
            title: isBuy ? 'Pay via' : 'Payment method',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: methods.map((m) {
              final isSelected = selected?.id == m.id;
              return GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                    isSelected ? c.primary : c.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? c.primary : c.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.logo != null && m.logo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: Image.network(
                              m.logo!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.account_balance_rounded,
                                size: 16,
                                color: isSelected
                                    ? c.onPrimary
                                    : c.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: 16,
                            color: isSelected
                                ? c.onPrimary
                                : c.textSecondary,
                          ),
                        ),
                      Text(
                        m.name,
                        style: TextStyle(
                          color: isSelected
                              ? c.onPrimary
                              : c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded,
                            color: c.onPrimary, size: 15),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (isBuy && merchantAccount != null) ...[
            const SizedBox(height: 16),
            _Divider(c: c),
            const SizedBox(height: 14),
            _SendToSection(c: c, account: merchantAccount!),
          ],
        ],
      ),
    );
  }
}

class _SendToSection extends StatelessWidget {
  const _SendToSection({required this.c, required this.account});
  final AppColor c;
  final UserPaymentAccountModel account;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, size: 11, color: c.success),
                  const SizedBox(width: 5),
                  Text(
                    'Send fiat to',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CopyableRow(
            c: c,
            label: 'Account name',
            value: account.accountName),
        if (account.accountNo != null)
          _CopyableRow(
              c: c,
              label: 'Account no.',
              value: account.accountNo!),
        if (account.label != null)
          _CopyableRow(c: c, label: 'Label', value: account.label!),
        if (account.instructions != null &&
            account.instructions!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            account.instructions!,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                showFloatingSnackBar(context,
                    message: 'Copied!', type: SnackBarType.success);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Icon(Icons.copy_rounded,
                        size: 13, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Receiver Card ────────────────────────────────────────────────────────────

class _ReceiverCard extends StatelessWidget {
  const _ReceiverCard({
    required this.c,
    required this.receiverIsCurrentActor,
    required this.receiverController,
    required this.validator,
    required this.defaultAddress,
  });
  final AppColor c;
  final bool receiverIsCurrentActor;
  final TextEditingController receiverController;
  final FormFieldValidator<String> validator;
  final String? defaultAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            c: c,
            icon: Icons.wallet_rounded,
            title: 'Receiver address',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: receiverController,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: defaultAddress ?? 'G...',
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 12.5),
              helperText: receiverIsCurrentActor
                  ? 'Receiver address is your active Stellar wallet public address.'
                  : 'Receiver address is from your selected payment account (asset receiver address) when available.',
              helperStyle: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
              filled: true,
              fillColor: c.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
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
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              UpperCaseTextFormatter(),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Your Account Card ────────────────────────────────────────────────────────

class _YourAccountCard extends StatelessWidget {
  const _YourAccountCard({
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            c: c,
            icon: Icons.person_outline_rounded,
            title: 'Your payment account',
          ),
          const SizedBox(height: 14),
          if (accounts.isEmpty)
            _InlineWarn(
              c: c,
              message:
              'No active account for selected method. Add one in Payment Accounts.',
            )
          else
            DropdownButtonFormField<UserPaymentAccountModel>(
              value: selected,
              isExpanded: true,
              dropdownColor: c.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: c.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
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
                  borderSide:
                  BorderSide(color: c.primary, width: 1.5),
                ),
              ),
              items: accounts.map((a) {
                final label = (a.label ?? '').trim();
                final accountName = a.accountName.trim();
                final accountNo = (a.accountNo ?? '').trim();
                final fallback =
                accountName.isNotEmpty ? accountName : 'Saved account';
                final display = label.isNotEmpty
                    ? label
                    : '$fallback${accountNo.isNotEmpty ? ' · $accountNo' : ''}';
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
            ),
        ],
      ),
    );
  }
}

// ─── Terms Card ───────────────────────────────────────────────────────────────

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.c, required this.offer});
  final AppColor c;
  final OfferModel offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            c: c,
            icon: Icons.shield_outlined,
            title: 'Trade terms',
          ),
          const SizedBox(height: 12),
          _TermItem(
            c: c,
            text: 'Crypto is held in escrow until payment is confirmed.',
          ),
          if (offer.paymentWindowMinutes != null)
            _TermItem(
              c: c,
              text:
              'You have ${offer.paymentWindowMinutes} minutes to complete payment.',
            ),
          _TermItem(
            c: c,
            text: 'All disputes are handled through our support system.',
          ),
          if (offer.autoReply != null && offer.autoReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: 15, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offer.autoReply!,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  const _TermItem({required this.c, required this.text});
  final AppColor c;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.c,
    required this.icon,
    required this.title,
  });
  final AppColor c;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 14, color: c.textSecondary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.c});
  final AppColor c;

  @override
  Widget build(BuildContext context) =>
      Divider(color: c.border, height: 1, thickness: 1);
}

class _InlineWarn extends StatelessWidget {
  const _InlineWarn({required this.c, required this.message});
  final AppColor c;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: c.warning.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.warning.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded,
            size: 15, color: c.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: c.warning, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}

class _WarnCard extends StatelessWidget {
  const _WarnCard({required this.c, required this.message});
  final AppColor c;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.border),
    ),
    child: _InlineWarn(c: c, message: message),
  );
}

// ─── Error Body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded,
                color: c.error, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.textSecondary, fontSize: 13, height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Try again',
                style: TextStyle(
                  color: c.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Submit Bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.c,
    required this.typeColor,
    required this.isBuy,
    required this.asset,
    required this.submitting,
    required this.disabled,
    this.disabledLabel,
    this.onTap,
  });
  final AppColor c;
  final Color typeColor;
  final bool isBuy;
  final String asset;
  final bool submitting;
  final bool disabled;
  final String? disabledLabel;
  final VoidCallback? onTap;

  bool get _isDisabled => disabled || submitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: GestureDetector(
        onTap: _isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 58,
          decoration: BoxDecoration(
            color: _isDisabled ? c.border : typeColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _isDisabled
                ? null
                : [
              BoxShadow(
                color: typeColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: submitting
                ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.onPrimary,
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!disabled)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isBuy
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: c.onPrimary,
                      size: 18,
                    ),
                  ),
                Text(
                  disabled
                      ? (disabledLabel ?? 'Complete required fields')
                      : (isBuy
                      ? 'Confirm Buy $asset'
                      : 'Confirm Sell $asset'),
                  style: TextStyle(
                    color: _isDisabled
                        ? c.textSecondary
                        : c.onPrimary,
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}




