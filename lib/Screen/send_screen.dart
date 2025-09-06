import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Screen/qr_code_scanner.dart';
import 'package:next_fi/Services/seed_storage.dart';

// Shared UI kit
import 'SendAndReceieveWidgets/shared_widget_send_and_recieve.dart';

class SendScreen extends StatefulWidget {
  final String address;                 // fallback (replaced by derived)
  final String token;                   // XLM | USDC
  final double balance;
  final bool autoOpenScanner;

  /// optional recipient prefill
  final String? prefillAddress;         // if non-empty ⇒ auto-populate the recipient
  final String? prefillName;            // optional alias shown in confirm sheet

  const SendScreen({
    super.key,
    required this.address,
    required this.token,
    required this.balance,
    this.autoOpenScanner = false,
    this.prefillAddress,
    this.prefillName,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  // Wallet (Stellar)
  Wallet? _wallet;
  KeyPair? _keyPair;            // used to sign
  String? _stellarAddress;      // G...

  bool _isSending = false;

  // Stellar service + SDK
  late final StellarWalletService _stellar = StellarWalletService();
  late final StellarSDK _sdk = _stellar.sdk;
  bool get _isTestnet => identical(_sdk, StellarSDK.TESTNET);
  Network get _network => _isTestnet ? Network.TESTNET : Network.PUBLIC;

  // Issuers (match StellarWalletService defaults/overrides)
  static const String _USDC_ISSUER_MAINNET =
      'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
  static const String _USDC_ISSUER_TESTNET =
      'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';
  String get _usdcIssuer =>
      _isTestnet
          ? (_stellar.usdcIssuerOverrideTestnet ?? _USDC_ISSUER_TESTNET)
          : (_stellar.usdcIssuerOverrideMainnet ?? _USDC_ISSUER_MAINNET);

  Asset get _assetXlm => Asset.NATIVE;
  Asset get _assetUsdc => AssetTypeCreditAlphaNum4('USDC', _usdcIssuer);

  // Lightweight “estimate” / checks (USDC trustline etc.)
  Timer? _debounce;
  bool _checking = false;
  bool? _destHasUsdcTL;
  String? _checkMsg;
  String _lastCheckKey = ''; // from|to|amount|token

  @override
  void initState() {
    super.initState();
    // Prefill recipient if provided
    final pre = (widget.prefillAddress ?? '').trim();
    if (pre.isNotEmpty) _recipientController.text = pre;

    _loadWallet();

    if (widget.autoOpenScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanQRCode());
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /* ---------------- Wallet ---------------- */
  Future<void> _loadWallet() async {
    final mnemonic = await SeedStorage.getSeed();
    if (!mounted || mnemonic == null || mnemonic.isEmpty) return;

    try {
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet);

      setState(() {
        _wallet = wallet;
        _keyPair = kp;
        _stellarAddress = kp.accountId;
      });

      _scheduleChecks();
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  /* ---------------- Checks (dest trustline for USDC, simple guards) ---------------- */
  void _scheduleChecks() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runChecksIfNeeded);
  }

  bool _looksLikeStellar(String s) => s.isNotEmpty && s.startsWith('G') && s.length == 56;

  Future<void> _runChecksIfNeeded() async {
    final token = widget.token.toUpperCase();
    final from = (_stellarAddress ?? widget.address).trim();
    final to = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final key = '$from|$to|$amount|$token';
    if (amount <= 0 || !_looksLikeStellar(from) || !_looksLikeStellar(to)) {
      _lastCheckKey = '';
      setState(() {
        _checking = false;
        _destHasUsdcTL = null;
        _checkMsg = null;
      });
      return;
    }
    if (key == _lastCheckKey) return;
    _lastCheckKey = key;

    setState(() {
      _checking = true;
      _destHasUsdcTL = null;
      _checkMsg = null;
    });

    try {
      if (token == 'USDC') {
        // Recipient must have USDC trustline
        final hasTL = await _stellar.hasUsdcTrustline(to);
        if (!mounted) return;
        setState(() {
          _destHasUsdcTL = hasTL;
          _checkMsg = hasTL
              ? 'Recipient USDC trustline OK'
              : 'Recipient must add USDC trustline first.';
        });
      } else {
        // XLM needs no trustline
        if (!mounted) return;
        setState(() {
          _destHasUsdcTL = null;
          _checkMsg = 'Ready';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkMsg = 'Check failed');
    } finally {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  /* ---------------- Send ---------------- */

  /// Ensure SENDER has USDC trustline (creates if missing).
  Future<void> _ensureSenderUsdcTrustline() async {
    final kp = _keyPair!;
    // Check balances to see if trustline already exists
    final acc = await _sdk.accounts.account(kp.accountId);
    final exists = acc.balances.any(
          (b) => b.assetCode == 'USDC' && b.assetIssuer == _usdcIssuer,
    );
    if (exists) return;

    // Create trustline
    final tx = (TransactionBuilder(acc)
      ..addOperation(ChangeTrustOperationBuilder(_assetUsdc, '922337203685.4775807').build())
      ..setMaxOperationFee(100))
        .build();
    tx.sign(kp, _network);

    final res = await _sdk.submitTransaction(tx);
    if (!res.success) {
      throw Exception('ChangeTrust(USDC) failed: ${res.resultXdr}');
    }
  }

  Future<String> _sendPayment({
    required Asset asset,
    required String destination,
    required String amount, // already 7dp string
    String? memoText,
  }) async {
    final kp = _keyPair!;
    final acc = await _sdk.accounts.account(kp.accountId);

    final builder = TransactionBuilder(acc)
      ..addOperation(PaymentOperationBuilder(destination, asset, amount).build())
      ..setMaxOperationFee(100); // 100 stroops/op

    if (memoText != null && memoText.isNotEmpty) {
      builder.addMemo(Memo.text(memoText));
    }

    final tx = builder.build();
    tx.sign(kp, _network);
    final res = await _sdk.submitTransaction(tx);
    if (!res.success) {
      throw Exception('Payment failed: ${res.resultXdr}');
    }
    return res.hash!;
  }

  // ✅ Helper: works whether KeyPair.secretSeed is a String or bytes.
  String _seedStringFromKeyPair(KeyPair kp) {
    final dynamic ss = kp.secretSeed; // sdk types vary across versions
    if (ss == null) {
      throw Exception('KeyPair has no secret seed');
    }
    if (ss is String) {
      return ss; // already a base32 seed string (e.g., "SA...").
    }
    if (ss is Iterable<int>) {
      return String.fromCharCodes(ss); // convert Uint8List/bytes → String
    }
    throw Exception('Unsupported secretSeed type: ${ss.runtimeType}');
  }

  Future<void> _sendTokenNow() async {
    if (!_formKey.currentState!.validate()) return;

    final to = _recipientController.text.trim();
    final amt = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amt <= 0 || amt > widget.balance) {
      showFloatingSnackBar(context, message: 'Invalid amount', type: SnackBarType.error);
      return;
    }
    if (_keyPair == null || _stellarAddress == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded', type: SnackBarType.error);
      return;
    }

    setState(() => _isSending = true);
    try {
      final isXLM = widget.token.toUpperCase() == 'XLM';
      String txId;

      if (isXLM) {
        // If a profit address is configured in service, use the fee-split helper,
        // otherwise send full amount directly.
        if ((_stellar.profitAddress).trim().isNotEmpty) {
          final hashes = await _stellar.sendXlmWithFee(
            secretSeed: _seedStringFromKeyPair(_keyPair!),
            destination: to,
            amount: amt,
            memoText: null,
          );
          txId = hashes.first; // main transfer hash
        } else {
          txId = await _sendPayment(
            asset: _assetXlm,
            destination: to,
            amount: amt.toStringAsFixed(7),
          );
        }
      } else {
        // USDC: ensure sender trustline; recipient must already have it
        if (_destHasUsdcTL == false) {
          throw Exception('Recipient has no USDC trustline.');
        }
        await _ensureSenderUsdcTrustline();
        txId = await _sendPayment(
          asset: _assetUsdc,
          destination: to,
          amount: amt.toStringAsFixed(7),
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _showTxSubmittedModal(txId);

      if (mounted) {
        showFloatingSnackBar(
          context,
          message: '${amt.toStringAsFixed(6)} ${widget.token.toUpperCase()} sent',
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: 'Failed to send: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /* ---------------- UI helpers ---------------- */
  Future<void> _scanQRCode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (!mounted) return;
    if (code != null && code.isNotEmpty) {
      _recipientController.text = code.trim();
      HapticFeedback.lightImpact();
      _scheduleChecks();
    }
  }

  Future<void> _pickFromAddressBook() async {
    final picked = await Navigator.of(context).pushNamed<String>('/address-book');
    if (!mounted) return;
    if (picked != null && picked.trim().isNotEmpty) {
      _recipientController.text = picked.trim();
      HapticFeedback.selectionClick();
      _scheduleChecks();
    }
  }

  void _onTapPercent(double pct, {required bool isXLM}) {
    // Keep tiny buffer when sending XLM to avoid going below reserves (very conservative)
    final bufferXlm = isXLM ? 0.1 : 0.0;
    final maxSpend = isXLM ? (widget.balance - bufferXlm).clamp(0.0, widget.balance) : widget.balance;
    final v = (maxSpend * pct).clamp(0.0, widget.balance);
    _amountController.text = v.toStringAsFixed(6);
    HapticFeedback.selectionClick();
    _scheduleChecks();
  }

  void _onTapMax({required bool isXLM}) => _onTapPercent(1.0, isXLM: isXLM);

  Future<void> _showTxSubmittedModal(String txId) {
    final colors = AppColor.of(context);
    return showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('Transfer submitted', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary)),
              ]),
              const SizedBox(height: 8),
              SelectableText(txId, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: txId));
                      HapticFeedback.lightImpact();
                      if (mounted) showFloatingSnackBar(context, message: 'TxID copied', type: SnackBarType.success);
                    },
                    icon: Icon(LucideIcons.copy, size: 18, color: colors.primary),
                    label: Text('Copy TxID', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.primary.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  void _confirmAndSend(CurrencyProvider currency, bool isXLM) {
    final colors = AppColor.of(context);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fiat = isXLM ? currency.xlmToFiat(amount) : currency.usdcToFiat(amount);

    // Stellar fee ≈ 100 stroops/op = 0.0000100 XLM for a single Payment op
    const feePerOpXlm = 0.0000100;
    final ops = 1;
    final estFee = feePerOpXlm * ops;

    final toText = () {
      final addr = _recipientController.text.trim();
      final name = (widget.prefillName ?? '').trim();
      return name.isEmpty ? addr : '$name  •  $addr';
    }();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 10),
              Text('Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary)),
              const SizedBox(height: 8),
              ReviewRow(label: 'From', value: (_stellarAddress ?? widget.address), mono: true),
              ReviewRow(label: 'To', value: toText, mono: true),
              ReviewRow(label: 'Amount', value: '${amount.toStringAsFixed(6)} ${widget.token.toUpperCase()}'),
              ReviewRow(label: '≈ Fiat', value: fiatFmt.format(fiat)),
              const SizedBox(height: 6),
              ReviewRow(
                label: 'Network Fee',
                value: '≈ ${estFee.toStringAsFixed(6)} XLM (${ops} op)',
              ),
              if ((widget.token.toUpperCase() == 'USDC') && (_checking || _destHasUsdcTL == false || (_checkMsg ?? '').isNotEmpty)) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _checking ? 'Checking recipient trustline…' : (_checkMsg ?? ''),
                    style: TextStyle(
                      color: (_destHasUsdcTL == false) ? Colors.red : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.primary.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cancel', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendTokenNow();
                    },
                    icon: const Icon(LucideIcons.send, size: 18, color: Colors.white),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  /* ---------------- Build ---------------- */
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final isXLM = widget.token.toUpperCase() == 'XLM';
    final balanceFiat = isXLM ? currency.xlmToFiat(widget.balance) : currency.usdcToFiat(widget.balance);

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat('#,##0.00');

    final oneTokenInFiat = isXLM ? currency.xlmToFiat(1) : currency.usdcToFiat(1);
    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final fromAddress = _stellarAddress ?? widget.address;
    final t = widget.token.toUpperCase();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Send $t', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          // From chip (compact)
          if (fromAddress.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.badgeCheck, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(fromAddress,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Price + balance (compact)
          PriceHeader(
            token: widget.token,
            oneTokenInFiat: oneTokenInFiat,
            changePct: 0,
            rangeLabel: 'NOW',
            colors: colors,
            fiatFmt: fiatFmt,
          ),
          const SizedBox(height: 8),
          BalanceHeader(
            token: widget.token,
            amountToken: widget.balance,
            amountFiat: balanceFiat,
            colors: colors,
            numFmt: numFmt,
            fiatFmt: fiatFmt,
          ),

          const SizedBox(height: 14),

          // Simple hint card (Stellar fee info / trustline message)
          if (_checking || (_checkMsg ?? '').isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, color: colors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _checking ? 'Checking recipient...' : _checkMsg!,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Form (compact)
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: 'Recipient',
                    hintText: 'G... (Stellar address)',
                    filled: true,
                    fillColor: colors.primary.withOpacity(0.04),
                    prefixIcon: Icon(LucideIcons.contact, color: colors.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Address book',
                          icon: Icon(LucideIcons.contact, color: colors.primary),
                          onPressed: _pickFromAddressBook,
                        ),
                        IconButton(
                          tooltip: 'Scan QR',
                          icon: Icon(LucideIcons.qrCode, color: colors.primary),
                          onPressed: _scanQRCode,
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.primary.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.primary.withOpacity(0.35), width: 1.3),
                    ),
                  ),
                  onChanged: (_) => _scheduleChecks(),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter recipient address';
                    if (!_looksLikeStellar(v)) return 'Invalid Stellar address';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (${widget.token.toUpperCase()})',
                    filled: true,
                    fillColor: colors.primary.withOpacity(0.04),
                    prefixIcon: Icon(LucideIcons.coins, color: colors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.primary.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.primary.withOpacity(0.35), width: 1.3),
                    ),
                  ),
                  onChanged: (_) => _scheduleChecks(),
                  validator: (value) {
                    final v = double.tryParse(value?.trim() ?? '') ?? 0;
                    if (v <= 0) return 'Enter amount';
                    if (v > widget.balance) return 'Amount exceeds balance';
                    return null;
                  },
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    PctChip(label: '25%', onTap: () => _onTapPercent(0.25, isXLM: isXLM), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: '50%', onTap: () => _onTapPercent(0.50, isXLM: isXLM), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: '75%', onTap: () => _onTapPercent(0.75, isXLM: isXLM), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: 'MAX', onTap: () => _onTapMax(isXLM: isXLM), colors: colors),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(LucideIcons.banknote, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text('≈ ${fiatFmt.format(isXLM ? currency.xlmToFiat(typedAmount) : currency.usdcToFiat(typedAmount))}',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending || _keyPair == null
                  ? null
                  : () {
                if (_formKey.currentState!.validate()) {
                  HapticFeedback.selectionClick();
                  _confirmAndSend(currency, isXLM);
                }
              },
              icon: _isSending
                  ? const SizedBox.shrink()
                  : const Icon(LucideIcons.send, color: Colors.white, size: 18),
              label: _isSending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Send ${widget.token.toUpperCase()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- tiny util ---------------- */
void unawaited(Future<void> f) {}
