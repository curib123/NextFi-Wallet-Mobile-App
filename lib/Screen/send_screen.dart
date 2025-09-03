import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:next_fi/Screen/qr_code_scanner.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Components/SnackBar.dart';

import 'package:next_fi/Services/seed_storage.dart';
import 'package:next_fi/Services/tron_wallet_service.dart';

class SendScreen extends StatefulWidget {
  final String address; // fallback (will be replaced by derived)
  final String token;   // TRX or USDT
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

  // Price UI
  static const _ranges = <String, int>{ '24H': 1, '7D': 7, '30D': 30, '1Y': 365 };
  String _selectedRange = '24H';

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
    _loadWallet(); // ← load like your sample
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

  // ----------------------------------------------------------
  // Load wallet (your pattern)
  // ----------------------------------------------------------
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

      // Kick off resources + maybe an initial estimate if fields are prefilled
      await _fetchResources();
      _scheduleEstimate();
    } catch (e) {
      debugPrint('Failed to load Tron wallet: $e');
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  // ----------------------------------------------------------
  // Resource fetchers (Bandwidth + Energy) for current address
  // ----------------------------------------------------------
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

  // ----------------------------------------------------------
  // USDT preflight (estimate)
  // ----------------------------------------------------------
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

  // ----------------------------------------------------------
  // Send
  // ----------------------------------------------------------
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

  // ----------------------------------------------------------
  // UI helpers
  // ----------------------------------------------------------
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

  double _computeChangePct(List<double> history, int days) {
    if (history.length < 2 || days <= 0) return 0.0;
    final last = history.last;
    final refIdx = math.max(0, history.length - 1 - days);
    final ref = history[refIdx];
    if (ref <= 0) return 0.0;
    return ((last / ref) - 1.0) * 100.0;
  }

  List<double> _sliceForRange(List<double> history, int days) {
    if (history.isEmpty) return history;
    final start = math.max(0, history.length - (days + 1));
    return history.sublist(start);
  }

  void _onTapMax() {
    _amountController.text = widget.balance.toStringAsFixed(6);
    HapticFeedback.selectionClick();
    _scheduleEstimate();
  }

  void _confirmAndSend(CurrencyProvider currency, bool isTRX) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fiat = isTRX ? currency.trxToFiat(amount) : currency.usdtToFiat(amount);
    final colors = AppColor.of(context);
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());

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
                    child: Text("Network: TRON (TRC20). Fees are paid in TRX.", style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
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

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final isTRX = widget.token.toUpperCase() == 'TRX';
    final history = isTRX ? currency.trxHistory : currency.usdtHistory;
    final priceStream = isTRX ? currency.trxPriceStream : currency.usdtPriceStream;

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat("#,##0.00");

    final selectedDays = _ranges[_selectedRange]!;
    final changePct = _computeChangePct(history, selectedDays);
    final changeUp = changePct >= 0;
    final changeColor = changeUp ? Colors.green : Colors.red;
    final changeIcon = changeUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight;

    final chartHistory = _sliceForRange(history, selectedDays);
    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);

    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final typedFiat = isTRX ? currency.trxToFiat(typedAmount) : currency.usdtToFiat(typedAmount);

    // Derived resource values
    final bwLimitTotal = _freeNetLimit + _netLimit;
    final bwUsedTotal  = _freeNetUsed + _netUsed;
    final bwRemain     = math.max(0, bwLimitTotal - bwUsedTotal);
    final enRemain     = math.max(0, _energyLimit - _energyUsed);

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
            _TokenPill(token: widget.token, colors: colors),
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
              if (_privateKey == null) Container(
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
                        Tooltip(
                          message: _tronAddressHex41!,
                          child: const Icon(LucideIcons.info, size: 16),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Price + change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.wallet, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "1 ${widget.token.toUpperCase()} ≈ ${fiatFmt.format(oneTokenInFiat)}",
                        style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: changeColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(changeIcon, size: 14, color: changeColor),
                          const SizedBox(width: 6),
                          Text("${changeUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                              style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          const SizedBox(width: 6),
                          Text(_selectedRange,
                              style: TextStyle(color: colors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Range selector
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _ranges.keys.map((label) {
                  final selected = _selectedRange == label;
                  return ChoiceChip(
                    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedRange = label),
                    backgroundColor: colors.surface,
                    selectedColor: colors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(color: selected ? colors.primary : colors.textSecondary),
                    side: BorderSide(color: selected ? colors.primary.withOpacity(0.35) : colors.primary.withOpacity(0.15)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Chart
              _buildChart(colors, history, fiatFmt, changeUp),
              const SizedBox(height: 14),

              // Resources card
              _buildResourcesCard(colors, enRemain),
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
                    Text(
                      "≈ ${fiatFmt.format(isTRX ? currency.trxToFiat(widget.balance) : currency.usdtToFiat(widget.balance))}",
                      style: TextStyle(color: colors.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
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

  // --- UI sub-widgets ---
  Widget _buildChart(AppColor colors, List<double> chartHistory, NumberFormat fiatFmt, bool changeUp) {
    if (chartHistory.isEmpty || chartHistory.length < 2) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withOpacity(0.08)),
        ),
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    final c = changeUp ? Colors.green : Colors.red;
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: chartHistory.reduce(math.min) * 0.995,
          maxY: chartHistory.reduce(math.max) * 1.005,
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                fiatFmt.format(s.y),
                TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
              )).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: [for (int i = 0; i < chartHistory.length; i++) FlSpot(i.toDouble(), chartHistory[i])],
              gradient: LinearGradient(colors: [c, c.withOpacity(0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [c.withOpacity(0.18), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, p, bar, index) {
                  final isLast = index == chartHistory.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 3.6 : 0,
                    color: isLast ? c : Colors.transparent,
                    strokeWidth: isLast ? 2 : 0,
                    strokeColor: Colors.white,
                  );
                },
              ),
              barWidth: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesCard(AppColor colors, int enRemain) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: _resLoading
          ? Row(
        children: [
          const SizedBox(width: 4),
          SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
          const SizedBox(width: 12),
          Text("Loading resources…", style: TextStyle(color: colors.textSecondary)),
        ],
      )
          : (_resError != null)
          ? Row(
        children: [
          Icon(LucideIcons.alertCircle, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_resError!, style: const TextStyle(color: Colors.red))),
          TextButton(onPressed: _fetchResources, child: const Text("Retry")),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResBar(
            icon: LucideIcons.activity,
            label: "Energy",
            used: _energyUsed,
            total: _energyLimit,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _ResBar(
            icon: LucideIcons.zap,
            label: "Bandwidth",
            used: _freeNetUsed + _netUsed,
            total: _freeNetLimit + _netLimit,
            colors: colors,
          ),
          if (widget.token.toUpperCase() == 'USDT') ...[
            const SizedBox(height: 10),
            _usdtEstimateBlock(colors, enRemain),
          ],
        ],
      ),
    );
  }

  Widget _usdtEstimateBlock(AppColor colors, int enRemain) {
    final rec = _recommendedFeeLimitSun;
    final req = _estEnergyRequired;
    final status = _estimating
        ? Row(children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
      const SizedBox(width: 8),
      Text("Estimating USDT transfer…", style: TextStyle(color: colors.textSecondary)),
    ])
        : (req == null && rec == null)
        ? Text("Enter a valid recipient and amount to estimate energy.", style: TextStyle(color: colors.textSecondary, fontSize: 12.5))
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KV("Est. Energy", req?.toString() ?? "—", colors),
        _KV("Recommended fee_limit (SUN)", rec?.toString() ?? "—", colors),
        if (req != null)
          Row(
            children: [
              Icon(req <= enRemain ? LucideIcons.check : LucideIcons.alertTriangle,
                  size: 16, color: req <= enRemain ? Colors.green : Colors.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req <= enRemain
                      ? "Sufficient energy available."
                      : "Energy may be insufficient; TRX will be burned up to fee_limit.",
                  style: TextStyle(color: req <= enRemain ? Colors.green : Colors.orange, fontSize: 12.5),
                ),
              ),
            ],
          ),
        if (_estimateMsg != null && _estimateMsg!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(_estimateMsg!, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: status,
    );
  }
}

// --- Small UI helpers ---
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

class _TokenPill extends StatelessWidget {
  const _TokenPill({required this.token, required this.colors});
  final String token;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(token.toUpperCase() == 'TRX' ? LucideIcons.sparkle : LucideIcons.banknote, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text(token.toUpperCase(), style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _ResBar extends StatelessWidget {
  const _ResBar({
    required this.icon,
    required this.label,
    required this.used,
    required this.total,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final int used;
  final int total;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final remain = math.max(0, total - used);
    final pct = total > 0 ? remain / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text("$remain / $total",
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: colors.primary.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      ],
    );
  }
}

Widget _KV(String k, String v, AppColor colors) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(k, style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
        const Spacer(),
        Text(v, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
