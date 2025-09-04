// lib/Screen/send_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Screen/qr_code_scanner.dart';

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

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

  // Wallet (loaded like your snippet)
  Uint8List? _privateKey;
  String? _tronAddress;
  String? _tronAddressHex41;

  bool _isSending = false;

  // Price range state (shared)
  PriceRange _selected = PriceRange.h24;

  // Tron service
  late final TronWalletService _tron = TronWalletService(const TronClientConfig());
  // If custom: TronClientConfig(baseUrl: 'https://api.trongrid.io', tronProApiKey: '...')

  // Resources (Bandwidth/Energy)
  static const String _baseUrl = 'https://api.trongrid.io'; // change for Shasta/custom
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

  // ---------------- Wallet & Resources ----------------
  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;
    if (storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final privKey = TronWalletService.derivePrivateKey(storedMnemonic);
      final pubKey  = TronWalletService.publicKeyFromPrivateKey(privKey);
      final address = TronWalletService.tronAddressFromPublicKey(pubKey);

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

      await _fetchResources();
      _scheduleEstimate();
    } catch (e) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _fetchResources() async {
    final addr = _tronAddress ?? widget.address;
    if (addr.isEmpty) return;

    setState(() {
      _resLoading = true;
      _resError = null;
    });
    try {
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'address': addr, 'visible': true});

      // Bandwidth
      final netUri = Uri.parse('$_baseUrl/wallet/getaccountnet');
      final netRes = await http.post(netUri, headers: headers, body: body).timeout(const Duration(seconds: 15));
      final netJ = jsonDecode(netRes.body) as Map<String, dynamic>;
      _freeNetLimit = (netJ['freeNetLimit'] as num?)?.toInt() ?? 0;
      _freeNetUsed  = (netJ['freeNetUsed']  as num?)?.toInt() ?? 0;
      _netLimit     = (netJ['NetLimit']     as num?)?.toInt() ?? 0;
      _netUsed      = (netJ['NetUsed']      as num?)?.toInt() ?? 0;

      // Energy
      final resUri = Uri.parse('$_baseUrl/wallet/getaccountresource');
      final resRes = await http.post(resUri, headers: headers, body: body).timeout(const Duration(seconds: 15));
      final resJ = jsonDecode(resRes.body) as Map<String, dynamic>;
      _energyLimit = (resJ['EnergyLimit'] as num?)?.toInt() ?? 0;
      _energyUsed  = (resJ['EnergyUsed']  as num?)?.toInt() ?? 0;
    } catch (e) {
      _resError = "Failed to load resources";
    } finally {
      if (mounted) setState(() => _resLoading = false);
    }
  }

  // ---------------- Estimate (USDT) ----------------
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

  // ---------------- Send ----------------
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
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColor.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        builder: (_) {
          final colors = AppColor.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(999))),
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
                SelectableText(txId, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontFamily: 'monospace', fontSize: 12.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: txId));
                          HapticFeedback.lightImpact();
                          if (mounted) showFloatingSnackBar(context, message: "TxID copied", type: SnackBarType.success);
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

      if (mounted) {
        showFloatingSnackBar(context, message: "${amount.toStringAsFixed(6)} ${widget.token} sent", type: SnackBarType.success);
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

  // ---------------- UI helpers ----------------
  Future<void> _scanQRCode() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QRScannerScreen()));
    if (!mounted) return;
    if (code != null && code.isNotEmpty) {
      _recipientController.text = code.trim();
      HapticFeedback.lightImpact();
      showFloatingSnackBar(context, message: "Address scanned", type: SnackBarType.success);
      _scheduleEstimate();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _recipientController.text = text;
      HapticFeedback.selectionClick();
      if (!mounted) return;
      showFloatingSnackBar(context, message: "Pasted from clipboard", type: SnackBarType.success);
      _scheduleEstimate();
    }
  }

  bool _looksLikeTron(String s) => s.isNotEmpty && s.startsWith('T') && s.length >= 30 && s.length <= 45;

  void _onTapMax() {
    _amountController.text = widget.balance.toStringAsFixed(6);
    HapticFeedback.selectionClick();
    _scheduleEstimate();
  }

  void _confirmAndSend(CurrencyProvider currency, bool isTRX) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fiat = isTRX ? currency.trxToFiat(amount) : currency.usdtToFiat(amount);
    final colors = AppColor.of(context);

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
              _ReviewRow(label: "From", value: (_tronAddress ?? widget.address), mono: true),
              _ReviewRow(label: "To", value: _recipientController.text, mono: true),
              _ReviewRow(label: "Amount", value: "${amount.toStringAsFixed(6)} ${widget.token.toUpperCase()}"),
              _ReviewRow(label: "≈ Fiat", value: fiatFmt.format(fiat)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Network: TRON (TRC20). Fees are paid in TRX.",
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
                  ),
                ],
              ),
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

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final isTRX = widget.token.toUpperCase() == 'TRX';
    final history = switch (_selected) {
      PriceRange.h24 => isTRX ? currency.trxHistory24h : currency.usdtHistory24h,
      PriceRange.d7  => isTRX ? currency.trxHistory7   : currency.usdtHistory7,
      PriceRange.d30 => isTRX ? currency.trxHistory30  : currency.usdtHistory30,
      PriceRange.y1  => isTRX ? currency.trxHistory365 : currency.usdtHistory365,
    };
    final priceStream = isTRX ? currency.trxPriceStream : currency.usdtPriceStream;

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat("#,##0.00");

    final changePct = pctChangeFromSeries(history);
    final changeUp = changePct >= 0;
    final changeColor = changeUp ? Colors.green : Colors.red;

    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);
    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final typedFiat = isTRX ? currency.trxToFiat(typedAmount) : currency.usdtToFiat(typedAmount);

    // Derived resource values
    final bwLimitTotal = _freeNetLimit + _netLimit;
    final bwUsedTotal  = _freeNetUsed + _netUsed;

    final fromAddress = _tronAddress ?? widget.address;

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
            onPressed: _fetchResources,
          ),
        ],
      ),
      body: StreamBuilder<double>(
        stream: priceStream,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              // Wallet banner if not loaded
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
                        child: Text("Wallet not loaded yet. Please ensure your mnemonic is stored.",
                            style: TextStyle(color: colors.textSecondary)),
                      ),
                      TextButton(onPressed: _loadWallet, child: const Text("Load")),
                    ],
                  ),
                ),

              // From address chip (derived)
              if (fromAddress.isNotEmpty) ...[
                const SizedBox(height: 8),
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
                        child: Text(
                          fromAddress,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_tronAddressHex41 != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(message: _tronAddressHex41!, child: const Icon(LucideIcons.info, size: 16)),
                      ]
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Price + change header
              PriceHeader(
                token: widget.token,
                oneTokenInFiat: oneTokenInFiat,
                changePct: changePct,
                rangeLabel: kRangeLabel[_selected]!,
                colors: colors,
                fiatFmt: fiatFmt,
              ),
              const SizedBox(height: 12),

              // Range selector
              RangeSegmented(
                selected: _selected,
                onChanged: (r) => setState(() => _selected = r),
                colors: colors,
              ),
              const SizedBox(height: 12),

              // Chart
              MainLineChart(history: history, changeColor: changeColor, fiatFmt: fiatFmt, colors: colors),
              const SizedBox(height: 14),

              // Resources card
              ResourcesCard(
                loading: _resLoading,
                errorText: _resError,
                onRetry: _fetchResources,
                energyUsed: _energyUsed,
                energyLimit: _energyLimit,
                bandwidthUsed: bwUsedTotal,
                bandwidthLimit: bwLimitTotal,
                colors: colors,
              ),
              const SizedBox(height: 16),

              // Balance
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Text("${numFmt.format(widget.balance)} ${widget.token.toUpperCase()}",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text("≈ ${fiatFmt.format(isTRX ? currency.trxToFiat(widget.balance) : currency.usdtToFiat(widget.balance))}",
                        style: TextStyle(color: colors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _recipientController,
                      decoration: InputDecoration(
                        labelText: "Recipient Address",
                        hintText: "T... (TRON address)",
                        prefixIcon: Icon(LucideIcons.user, color: colors.primary),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Paste",
                              icon: Icon(LucideIcons.clipboardPaste, color: colors.primary),
                              onPressed: _pasteFromClipboard,
                            ),
                            IconButton(
                              tooltip: "Scan QR",
                              icon: Icon(LucideIcons.qrCode, color: colors.primary),
                              onPressed: _scanQRCode,
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        prefixIcon: Icon(LucideIcons.coins, color: colors.primary),
                        suffixIcon: InkWell(
                          onTap: _onTapMax,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: colors.primary.withOpacity(0.25)),
                              ),
                              child: Text("MAX", style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _scheduleEstimate(),
                      validator: (value) {
                        final v = double.tryParse(value?.trim() ?? "") ?? 0;
                        if (v <= 0) return "Enter amount";
                        if (v > widget.balance) return "Amount exceeds balance";
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(LucideIcons.banknote, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 6),
                        Text("≈ ${fiatFmt.format(typedFiat)}",
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(LucideIcons.info, size: 14, color: colors.textSecondary),
                            const SizedBox(width: 6),
                            Text("Fees paid in TRX", style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Send button
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
                      : Text("Send ${widget.token.toUpperCase()}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Safety note
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
          );
        },
      ),
    );
  }
}

// Small UI helper kept locally (review rows)
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12.5))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
