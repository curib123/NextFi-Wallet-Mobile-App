// lib/Screen/send_screen.dart
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
  final String address; // fallback (replaced by derived)
  final String token;   // TRX | USDT
  final double balance;
  final bool autoOpenScanner;

  const SendScreen({
    super.key,
    required this.address,
    required this.token,
    required this.balance,
    this.autoOpenScanner = false,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Wallet
  Uint8List? _privateKey;
  String? _tronAddress;
  String? _tronAddressHex41;

  bool _isSending = false;

  // Tron service
  late final TronWalletService _tron = TronWalletService(const TronClientConfig());

  // Resources (Bandwidth/Energy) – now loaded via TronWalletService
  bool _resLoading = true;
  String? _resError;
  int _freeNetLimit = 0, _freeNetUsed = 0, _netLimit = 0, _netUsed = 0;
  int _energyLimit = 0, _energyUsed = 0;

  // USDT preflight estimate
  Timer? _debounce;
  bool _estimating = false;
  int? _estEnergyRequired;
  int? _recommendedFeeLimitSun;
  bool? _willSucceed;
  String? _estimateMsg;

  @override
  void initState() {
    super.initState();
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
    if (!mounted) return;
    if (storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final privKey = TronWalletService.derivePrivateKey(storedMnemonic);
      final address = TronWalletService.tronAddressFromMnemonic(storedMnemonic);

      String? hex41;
      try {
        hex41 = TronWalletService.tronBase58ToHex(address);
      } catch (_) {
        hex41 = null;
      }

      setState(() {
        _privateKey = privKey;
        _tronAddress = address;
        _tronAddressHex41 = hex41;
      });

      await _fetchResources(); // cached by service
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
      // Use service wrappers (with built-in TTL cache)
      final net = await _tron.getAccountNet(addr, forceRefresh: forceRefresh);
      final res = await _tron.getAccountResource(addr, forceRefresh: forceRefresh);

      _freeNetLimit = net['freeNetLimit'] ?? 0;
      _freeNetUsed  = net['freeNetUsed']  ?? 0;
      _netLimit     = net['NetLimit']     ?? 0;
      _netUsed      = net['NetUsed']      ?? 0;

      _energyLimit  = res['EnergyLimit']  ?? 0;
      _energyUsed   = res['EnergyUsed']   ?? 0;
    } catch (_) {
      _resError = "Failed to load resources";
    } finally {
      if (mounted) setState(() => _resLoading = false);
    }
  }

  /* ---------------- Estimate (USDT) ---------------- */
  void _scheduleEstimate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _estimateIfNeeded);
  }

  Future<void> _estimateIfNeeded() async {
    final isUSDT = widget.token.toUpperCase() == 'USDT';
    final from = _tronAddress ?? widget.address;
    final recipient = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (!isUSDT || amount <= 0 || !_looksLikeTron(recipient) || from.isEmpty) {
      setState(() {
        _estimating = false;
        _estEnergyRequired = null;
        _recommendedFeeLimitSun = null;
        _willSucceed = null;
        _estimateMsg = null;
      });
      return;
    }

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
        toAddress: recipient,
        amount: amount,
      );
      setState(() {
        _estEnergyRequired = (est['energy_required'] as int?) ?? (est['energy_used'] as int?);
        _recommendedFeeLimitSun = est['recommended_fee_limit_sun'] as int?;
        _willSucceed = est['will_succeed'] as bool?;
        _estimateMsg = (est['raw']?['message'] as String?)?.trim();
      });
    } catch (_) {
      setState(() {
        _estimateMsg = "Estimate failed";
      });
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  /* ---------------- Send ---------------- */
  Future<void> _sendTokenNow() async {
    if (!_formKey.currentState!.validate()) return;

    final recipient = _recipientController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (amount <= 0 || amount > widget.balance) {
      showFloatingSnackBar(context, message: "Invalid amount", type: SnackBarType.error);
      return;
    }
    if (_privateKey == null) {
      showFloatingSnackBar(context, message: "Wallet not loaded", type: SnackBarType.error);
      return;
    }

    setState(() => _isSending = true);

    try {
      final isTRX = widget.token.toUpperCase() == 'TRX';
      String txId;

      if (isTRX) {
        final int sun = (amount * 1e6).round();
        txId = await _tron.sendTrx(
          privateKey: _privateKey!,
          toAddress: recipient,
          amountSun: sun,
        );
      } else {
        txId = await _tron.sendUsdt(
          privateKey: _privateKey!,
          toAddress: recipient,
          amount: amount,
          feeLimitSun: (_recommendedFeeLimitSun ?? 5_000_000),
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      await _showTxSubmittedModal(txId);

      if (mounted) {
        showFloatingSnackBar(
          context,
          message: "${amount.toStringAsFixed(6)} ${widget.token} sent",
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } on TronError catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: e.message, type: SnackBarType.error);
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(context, message: "Failed to send: $e", type: SnackBarType.error);
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
      showFloatingSnackBar(context, message: "Address scanned", type: SnackBarType.success);
      _scheduleEstimate();
    }
  }

  Future<void> _pickFromAddressBook() async {
    final picked = await Navigator.of(context).pushNamed<String>('/address-book');
    if (!mounted) return;
    if (picked != null && picked.trim().isNotEmpty) {
      _recipientController.text = picked.trim();
      HapticFeedback.selectionClick();
      showFloatingSnackBar(context, message: "Address selected", type: SnackBarType.success);
      _scheduleEstimate();
    }
  }

  bool _looksLikeTron(String s) => s.isNotEmpty && s.startsWith('T') && s.length >= 30 && s.length <= 45;

  void _onTapPercent(double pct, {required bool isTRX}) {
    final bufferTrx = isTRX ? 0.2 : 0.0; // ~0.2 TRX buffer
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.checkCircle2, color: Colors.green, size: 22),
                  const SizedBox(width: 8),
                  Text("Transfer submitted", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                txId,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontFamily: 'monospace', fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: txId));
                        HapticFeedback.lightImpact();
                        if (mounted) {
                          showFloatingSnackBar(context, message: "TxID copied", type: SnackBarType.success);
                        }
                      },
                      icon: Icon(LucideIcons.copy, size: 18, color: colors.primary),
                      label: Text("Copy TxID", style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                      label: const Text("Done"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmAndSend(CurrencyProvider currency, bool isTRX) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fiat = isTRX ? currency.trxToFiat(amount) : currency.usdtToFiat(amount);
    final colors = AppColor.of(context);

    final feeLimitSun = _recommendedFeeLimitSun ?? 5_000_000; // default ~5 TRX cap
    final estFeeTrx = feeLimitSun / 1e6;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 12),
              Text("Review Transfer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary)),
              const SizedBox(height: 8),
              ReviewRow(label: "From", value: (_tronAddress ?? widget.address), mono: true),
              ReviewRow(label: "To", value: _recipientController.text, mono: true),
              ReviewRow(label: "Amount", value: "${amount.toStringAsFixed(6)} ${widget.token.toUpperCase()}"),
              ReviewRow(label: "≈ Fiat", value: fiatFmt.format(fiat)),
              const SizedBox(height: 8),

              if (!isTRX) ...[
                Row(
                  children: [
                    Icon(LucideIcons.zap, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _estimating
                            ? "Estimating Energy & fee limit…"
                            : (_willSucceed == true
                            ? "Est. Energy: ${_estEnergyRequired ?? 0} | Fee limit: ${feeLimitSun.toString()} SUN (~${estFeeTrx.toStringAsFixed(3)} TRX)"
                            : "Estimation suggests higher energy may be required. Fee limit: ${feeLimitSun.toString()} SUN (~${estFeeTrx.toStringAsFixed(3)} TRX)"),
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (_estimateMsg?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(LucideIcons.info, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _estimateMsg!,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    Icon(LucideIcons.flame, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "TRX transfers consume Bandwidth first. If insufficient, a small amount of TRX will be burned as fees.",
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(LucideIcons.x, color: colors.primary, size: 18),
                      label: Text("Cancel", style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                      label: const Text("Confirm"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
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
    final numFmt = NumberFormat("#,##0.00");

    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);
    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final typedFiat = isTRX ? currency.trxToFiat(typedAmount) : currency.usdtToFiat(typedAmount);

    final bwLimitTotal = _freeNetLimit + _netLimit;
    final bwUsedTotal  = _freeNetUsed + _netUsed;

    final fromAddress = _tronAddress ?? widget.address;
    final t = (widget.token).toUpperCase();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TokenPill(token: widget.token, colors: colors),
            const SizedBox(width: 8),
            Text("Send", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Refresh resources",
            icon: Icon(LucideIcons.refreshCcw, color: colors.textPrimary),
            onPressed: () => _fetchResources(forceRefresh: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          if (_privateKey == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.key, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Wallet not loaded yet. Please ensure your mnemonic is stored.",
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  TextButton(onPressed: _loadWallet, child: const Text("Load")),
                ],
              ),
            ),

          PriceHeader(
            token: widget.token,
            oneTokenInFiat: oneTokenInFiat,
            changePct: 0,
            rangeLabel: 'NOW',
            colors: colors,
            fiatFmt: fiatFmt,
          ),
          const SizedBox(height: 12),

          BalanceHeader(
            token: widget.token,
            amountToken: widget.balance,
            amountFiat: balanceFiat,
            colors: colors,
            numFmt: numFmt,
            fiatFmt: fiatFmt,
          ),

          const SizedBox(height: 14),

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
            showEnergy:    t == 'USDT' || (t != 'TRX' && t != 'USDT'),
            showBandwidth: t == 'TRX'  || (t != 'TRX' && t != 'USDT'),
            showActions: true,
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: "Recipient Address",
                    hintText: "T... (TRON address)",
                    filled: true,
                    fillColor: colors.primary.withOpacity(0.04),
                    prefixIcon: Icon(LucideIcons.contact, color: colors.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: "Pick from address book",
                          icon: Icon(LucideIcons.contact, color: colors.primary),
                          onPressed: _pickFromAddressBook,
                        ),
                        IconButton(
                          tooltip: "Scan QR",
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
                    if (v.isEmpty) return "Enter recipient address";
                    if (!_looksLikeTron(v)) return "Invalid TRON address";
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Amount (${widget.token.toUpperCase()})",
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
                    final v = double.tryParse(value?.trim() ?? "") ?? 0;
                    if (v <= 0) return "Enter amount";
                    if (v > widget.balance) return "Amount exceeds balance";
                    return null;
                  },
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    PctChip(label: "25%", onTap: () => _onTapPercent(0.25, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: "50%", onTap: () => _onTapPercent(0.50, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: "75%", onTap: () => _onTapPercent(0.75, isTRX: isTRX), colors: colors),
                    const SizedBox(width: 8),
                    PctChip(label: "MAX", onTap: () => _onTapMax(isTRX: isTRX), colors: colors),
                  ],
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.banknote, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      "≈ ${fiatFmt.format(typedFiat)}",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(LucideIcons.info, size: 14, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          isTRX ? "Bandwidth first, else TRX burned" : "Fees (Energy) paid in TRX",
                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

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
              icon: _isSending ? const SizedBox.shrink() : const Icon(LucideIcons.send, color: Colors.white, size: 18),
              label: _isSending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                "Send ${widget.token.toUpperCase()}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.alertTriangle, color: colors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Double-check the recipient address. Transfers on TRON are irreversible.",
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.28),
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
