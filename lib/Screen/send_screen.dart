import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Screen/qr_code_scanner.dart';
import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron/tron_wallet_service.dart';

// Shared UI kit
import 'SendAndReceieveWidgets/shared_widget_send_and_recieve.dart';

class SendScreen extends StatefulWidget {
  final String address;                 // fallback (replaced by derived)
  final String token;                   // TRX | USDT
  final double balance;
  final bool autoOpenScanner;

  /// NEW: optional recipient prefill
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

  // Wallet
  Uint8List? _privateKey;
  String? _tronAddress;
  String? _tronAddressHex41;

  bool _isSending = false;

  // Tron service
  late final TronWalletService _tron = TronWalletService(const TronClientConfig());

  // Resources (via service – assumed cached)
  bool _resLoading = true;
  String? _resError;
  int _freeNetLimit = 0, _freeNetUsed = 0, _netLimit = 0, _netUsed = 0;
  int _energyLimit = 0, _energyUsed = 0;

  // USDT preflight estimate (debounced + deduped)
  Timer? _debounce;
  bool _estimating = false;
  int? _estEnergyRequired;
  int? _recommendedFeeLimitSun;
  bool? _willSucceed;
  String? _estimateMsg;
  String _lastEstKey = ''; // from|to|amount|token

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
    _tron.dispose();
    super.dispose();
  }

  /* ---------------- Wallet & Resources ---------------- */
  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted || storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final privKey = TronWalletService.derivePrivateKey(storedMnemonic);
      final address = TronWalletService.tronAddressFromMnemonic(storedMnemonic);
      String? hex41;
      try {
        hex41 = TronWalletService.tronBase58ToHex(address);
      } catch (_) {}

      setState(() {
        _privateKey = privKey;
        _tronAddress = address;
        _tronAddressHex41 = hex41;
      });

      // Single resource load (service should cache); refresh only on pull
      unawaited(_fetchResources());
      _scheduleEstimate();
    } catch (_) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _fetchResources({bool forceRefresh = false}) async {
    final addr = (_tronAddress ?? widget.address).trim();
    if (addr.isEmpty) return;

    setState(() {
      _resLoading = true;
      _resError = null;
    });
    try {
      final net = await _tron.getAccountNet(addr, forceRefresh: forceRefresh);
      final res = await _tron.getAccountResource(addr, forceRefresh: forceRefresh);

      _freeNetLimit = net['freeNetLimit'] ?? 0;
      _freeNetUsed  = net['freeNetUsed']  ?? 0;
      _netLimit     = net['NetLimit']     ?? 0;
      _netUsed      = net['NetUsed']      ?? 0;

      _energyLimit  = res['EnergyLimit']  ?? 0;
      _energyUsed   = res['EnergyUsed']   ?? 0;
    } catch (_) {
      _resError = 'Failed to load resources';
    } finally {
      if (mounted) setState(() => _resLoading = false);
    }
  }

  /* ---------------- Estimate (USDT only) ---------------- */
  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _estimateIfNeeded);
  }

  bool _looksLikeTron(String s) => s.isNotEmpty && s.startsWith('T') && s.length >= 30 && s.length <= 45;

  Future<void> _estimateIfNeeded() async {
    final isUSDT = widget.token.toUpperCase() == 'USDT';
    final from = (_tronAddress ?? widget.address).trim();
    final to = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    // Dedup key (avoid repeat calls for same tuple)
    final key = '$from|$to|$amount|${widget.token.toUpperCase()}';
    if (!isUSDT || amount <= 0 || !_looksLikeTron(to) || from.isEmpty) {
      _lastEstKey = '';
      setState(() {
        _estimating = false;
        _estEnergyRequired = null;
        _recommendedFeeLimitSun = null;
        _willSucceed = null;
        _estimateMsg = null;
      });
      return;
    }
    if (key == _lastEstKey) return; // unchanged → no extra call
    _lastEstKey = key;

    setState(() {
      _estimating = true;
      _estEnergyRequired = null;
      _recommendedFeeLimitSun = null;
      _willSucceed = null;
      _estimateMsg = null;
    });

    try {
      final est = await _tron.estimateUsdtTransfer(
        fromAddress: from,
        toAddress: to,
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        _estEnergyRequired = (est['energy_required'] as int?) ?? (est['energy_used'] as int?);
        _recommendedFeeLimitSun = est['recommended_fee_limit_sun'] as int?;
        _willSucceed = est['will_succeed'] as bool?;
        _estimateMsg = (est['raw']?['message'] as String?)?.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _estimateMsg = 'Estimate failed');
    } finally {
      if (!mounted) return;
      setState(() => _estimating = false);
    }
  }

  /* ---------------- Send ---------------- */
  Future<void> _sendTokenNow() async {
    if (!_formKey.currentState!.validate()) return;

    final to = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0 || amount > widget.balance) {
      showFloatingSnackBar(context, message: 'Invalid amount', type: SnackBarType.error);
      return;
    }
    if (_privateKey == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded', type: SnackBarType.error);
      return;
    }

    setState(() => _isSending = true);
    try {
      final isTRX = widget.token.toUpperCase() == 'TRX';
      String txId;

      if (isTRX) {
        final sun = (amount * 1e6).round();
        txId = await _tron.sendTrx(privateKey: _privateKey!, toAddress: to, amountSun: sun);
      } else {
        txId = await _tron.sendUsdt(
          privateKey: _privateKey!,
          toAddress: to,
          amount: amount,
          feeLimitSun: (_recommendedFeeLimitSun ?? 5_000_000), // ~5 TRX default
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _showTxSubmittedModal(txId);

      if (mounted) {
        showFloatingSnackBar(
          context,
          message: '${amount.toStringAsFixed(6)} ${widget.token} sent',
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } on TronError catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: e.message, type: SnackBarType.error);
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
      _scheduleEstimate();
    }
  }

  Future<void> _pickFromAddressBook() async {
    final picked = await Navigator.of(context).pushNamed<String>('/address-book');
    if (!mounted) return;
    if (picked != null && picked.trim().isNotEmpty) {
      _recipientController.text = picked.trim();
      HapticFeedback.selectionClick();
      _scheduleEstimate();
    }
  }

  void _onTapPercent(double pct, {required bool isTRX}) {
    // Keep tiny buffer when sending TRX (bandwidth fallback)
    final bufferTrx = isTRX ? 0.2 : 0.0;
    final maxSpend = isTRX ? (widget.balance - bufferTrx).clamp(0.0, widget.balance) : widget.balance;
    final v = (maxSpend * pct).clamp(0.0, widget.balance);
    _amountController.text = v.toStringAsFixed(6);
    HapticFeedback.selectionClick();
    _scheduleEstimate();
  }

  void _onTapMax({required bool isTRX}) => _onTapPercent(1.0, isTRX: isTRX);

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

  void _confirmAndSend(CurrencyProvider currency, bool isTRX) {
    final colors = AppColor.of(context);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fiat = isTRX ? currency.trxToFiat(amount) : currency.usdtToFiat(amount);

    final feeLimitSun = _recommendedFeeLimitSun ?? 5_000_000;
    final estFeeTrx = feeLimitSun / 1e6;

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
              ReviewRow(label: 'From', value: (_tronAddress ?? widget.address), mono: true),
              ReviewRow(label: 'To', value: toText, mono: true),
              ReviewRow(label: 'Amount', value: '${amount.toStringAsFixed(6)} ${widget.token.toUpperCase()}'),
              ReviewRow(label: '≈ Fiat', value: fiatFmt.format(fiat)),

              if (!isTRX) ...[
                const SizedBox(height: 6),
                ReviewRow(
                  label: 'Energy/Fee',
                  value: _estimating
                      ? 'Estimating…'
                      : (_willSucceed == true
                      ? 'Energy ~${_estEnergyRequired ?? 0}  •  Limit ${feeLimitSun} SUN (~${estFeeTrx.toStringAsFixed(3)} TRX)'
                      : 'Limit ${feeLimitSun} SUN (~${estFeeTrx.toStringAsFixed(3)} TRX)'),
                ),
                if ((_estimateMsg ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(_estimateMsg!, style: TextStyle(color: colors.textSecondary, fontSize: 11.5)),
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

    final isTRX = widget.token.toUpperCase() == 'TRX';
    final balanceFiat = isTRX ? currency.trxToFiat(widget.balance) : currency.usdtToFiat(widget.balance);

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat('#,##0.00');

    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);
    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final typedFiat = isTRX ? currency.trxToFiat(typedAmount) : currency.usdtToFiat(typedAmount);

    final bwLimitTotal = _freeNetLimit + _netLimit;
    final bwUsedTotal = _freeNetUsed + _netUsed;

    final fromAddress = _tronAddress ?? widget.address;
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
        title: Text('Send ${t}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh resources',
            icon: Icon(LucideIcons.refreshCcw, color: colors.textPrimary),
            onPressed: () => _fetchResources(forceRefresh: true),
          ),
        ],
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
                  if (_tronAddressHex41 != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(message: _tronAddressHex41!, child: const Icon(LucideIcons.info, size: 16)),
                  ]
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

          const SizedBox(height: 12),

          // Resources (only once per load unless user refreshes)
          ResourcesCard(
            loading: _resLoading,
            errorText: _resError,
            onRetry: _fetchResources,
            energyUsed: _energyUsed,
            energyLimit: _energyLimit,
            bandwidthUsed: bwUsedTotal,
            bandwidthLimit: bwLimitTotal,
            colors: colors,
            showGuide: false,
            showEnergy: t == 'USDT' || (t != 'TRX' && t != 'USDT'),
            showBandwidth: t == 'TRX' || (t != 'TRX' && t != 'USDT'),
            showActions: true,
          ),

          const SizedBox(height: 14),

          // Form (compact)
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: 'Recipient',
                    hintText: 'T... (TRON address)',
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
                  onChanged: (_) => _scheduleEstimate(),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter recipient address';
                    if (!_looksLikeTron(v)) return 'Invalid TRON address';
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
                  onChanged: (_) => _scheduleEstimate(),
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
                    PctChip(label: '25%', onTap: () => _onTapPercent(0.25, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: '50%', onTap: () => _onTapPercent(0.50, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: '75%', onTap: () => _onTapPercent(0.75, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: 'MAX', onTap: () => _onTapMax(isTRX: isTRX), colors: colors),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(LucideIcons.banknote, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text('≈ ${fiatFmt.format(isTRX ? currency.trxToFiat(typedAmount) : currency.usdtToFiat(typedAmount))}',
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
              onPressed: _isSending || _privateKey == null
                  ? null
                  : () {
                if (_formKey.currentState!.validate()) {
                  HapticFeedback.selectionClick();
                  _confirmAndSend(currency, isTRX);
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
