// lib/Screen/receive_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

import 'SendAndReceieveWidgets/shared_widget_send_and_recieve.dart';

// === ReceiveScreen with TRX/USDT tabs ======================================
class ReceiveScreen extends StatefulWidget {
  final String address;
  final double trxBalance;
  final double usdtBalance;

  /// Optional initial token for the tab (defaults to TRX).
  final String initialToken; // 'TRX' | 'USDT'

  const ReceiveScreen({
    super.key,
    required this.address,
    required this.trxBalance,
    required this.usdtBalance,
    this.initialToken = 'TRX',
  });

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with SingleTickerProviderStateMixin {
  // Range state (shared)
  PriceRange _selected = PriceRange.h24;

  // ---- Tabs ----
  late final TabController _tabController;

  bool get isTRX => _tabController.index == 0;
  String get currentToken => isTRX ? 'TRX' : 'USDT';

  // ---- Resources (Bandwidth/Energy) ----
  static const String _baseUrl = 'https://api.trongrid.io'; // adjust for Shasta/custom
  bool _resLoading = true;
  String? _resError;
  int _freeNetLimit = 0, _freeNetUsed = 0, _netLimit = 0, _netUsed = 0;
  int _energyLimit = 0, _energyUsed = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialToken.toUpperCase() == 'USDT' ? 1 : 0,
    )..addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });

    _fetchResources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Pick the right history series from provider given token + range
  List<double> _historyFor(CurrencyProvider c, {required bool isTRX, required PriceRange r}) {
    if (isTRX) {
      return switch (r) {
        PriceRange.h24 => c.trxHistory24h,
        PriceRange.d7 => c.trxHistory7,
        PriceRange.d30 => c.trxHistory30,
        PriceRange.y1 => c.trxHistory365,
      };
    } else {
      return switch (r) {
        PriceRange.h24 => c.usdtHistory24h,
        PriceRange.d7 => c.usdtHistory7,
        PriceRange.d30 => c.usdtHistory30,
        PriceRange.y1 => c.usdtHistory365,
      };
    }
  }

  // ---- Fetch account resources for the displayed address ----
  Future<void> _fetchResources() async {
    final addr = widget.address;
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat("#,##0.00");

    // streams / prices based on selected token
    final priceStream = isTRX ? currency.trxPriceStream : currency.usdtPriceStream;
    final lastPrice   = isTRX ? currency.trxRate        : currency.usdtRate;
    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);

    // selected balances & history
    final double tokenBalance = isTRX ? widget.trxBalance : widget.usdtBalance;
    final double balanceFiat  = isTRX ? currency.trxToFiat(tokenBalance) : currency.usdtToFiat(tokenBalance);

    // derived for resource bars
    final bwLimitTotal = _freeNetLimit + _netLimit;
    final bwUsedTotal  = _freeNetUsed + _netUsed;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Receive",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Refresh resources",
            icon: Icon(LucideIcons.refreshCcw, color: colors.textPrimary),
            onPressed: _fetchResources,
          ),
          IconButton(
            tooltip: "Copy address",
            icon: Icon(LucideIcons.copy, color: colors.textPrimary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.address));
              HapticFeedback.lightImpact();
              if (mounted) {
                showFloatingSnackBar(context, message: "Address copied", type: SnackBarType.success);
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primary.withOpacity(0.1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: colors.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'TRX'),
                  Tab(text: 'USDT'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<double>(
        stream: priceStream,
        builder: (context, snapshot) {
          final _ = snapshot.data ?? lastPrice;
          final series = _historyFor(currency, isTRX: isTRX, r: _selected);

          final changePct = pctChangeFromSeries(series);
          final changeUp = changePct >= 0;
          final changeColor = changeUp ? Colors.green : Colors.red;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Price header
              PriceHeader(
                token: currentToken,
                oneTokenInFiat: oneTokenInFiat,
                changePct: changePct,
                rangeLabel: kRangeLabel[_selected]!,
                colors: colors,
                fiatFmt: fiatFmt,
              ),
              const SizedBox(height: 16),

              // Balance
              BalanceHeader(
                token: currentToken,
                amountToken: tokenBalance,
                amountFiat: balanceFiat,
                colors: colors,
                numFmt: numFmt,
                fiatFmt: fiatFmt,
              ),
              const SizedBox(height: 16),

              // Range segmented
              RangeSegmented(
                selected: _selected,
                onChanged: (r) => setState(() => _selected = r),
                colors: colors,
              ),
              const SizedBox(height: 12),

              // Main chart
              MainLineChart(
                history: series,
                changeColor: changeColor,
                fiatFmt: fiatFmt,
                colors: colors,
              ),
              const SizedBox(height: 14),

              // Resources (token-aware visibility)
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
                showEnergy:    !isTRX, // USDT only
                showBandwidth:  isTRX, // TRX only
              ),

              const SizedBox(height: 24),

              // QR card
              GestureDetector(
                onTap: () => _showQrDialog(context, colors),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: widget.address,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text("Tap to enlarge QR",
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Address card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.qrCode, color: colors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        widget.address,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: "Copy",
                      icon: Icon(LucideIcons.copy, color: colors.primary, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.address));
                        HapticFeedback.lightImpact();
                        showFloatingSnackBar(context, message: "Address copied", type: SnackBarType.success);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safety (token-aware)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.alertTriangle, color: colors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTRX
                            ? "Send only TRX (native TRON coin) to this address. Sending other networks or tokens may result in permanent loss."
                            : "Send only USDT on TRON (TRC20) to this address. Sending other networks or tokens may result in permanent loss.",
                        style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.28),
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

  void _showQrDialog(BuildContext context, AppColor colors) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: colors.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Receive $currentToken",
                    style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                QrImageView(
                  data: widget.address,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  widget.address,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontFamily: 'monospace', fontSize: 12.5, height: 1.2),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.address));
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          showFloatingSnackBar(context, message: "Address copied", type: SnackBarType.success);
                        },
                        icon: Icon(LucideIcons.copy, size: 18, color: colors.primary),
                        label: Text("Copy", style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
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
                        icon: const Icon(LucideIcons.x, size: 18, color: Colors.white),
                        label: const Text("Close"),
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
          ),
        );
      },
    );
  }
}
