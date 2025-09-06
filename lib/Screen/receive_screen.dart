// lib/Screen/receive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

import 'SendAndReceieveWidgets/shared_widget_send_and_recieve.dart';

// === ReceiveScreen with XLM/USDC tabs ======================================
class ReceiveScreen extends StatefulWidget {
  final String address;
  final double xlmBalance;
  final double usdcBalance;

  /// Optional initial token for the tab (defaults to XLM).
  final String initialToken; // 'XLM' | 'USDC'

  const ReceiveScreen({
    super.key,
    required this.address,
    required this.xlmBalance,
    required this.usdcBalance,
    this.initialToken = 'XLM',
  });

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with SingleTickerProviderStateMixin {
  // Range state (shared)
  PriceRange _selected = PriceRange.h24;

  // ---- Tabs ----
  late final TabController _tabController;

  bool get isXLM => _tabController.index == 0;
  String get currentToken => isXLM ? 'XLM' : 'USDC';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialToken.toUpperCase() == 'USDC' ? 1 : 0,
    )..addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Pick the right history series from provider given token + range
  List<double> _historyFor(CurrencyProvider c, {required bool isXLM, required PriceRange r}) {
    if (isXLM) {
      return switch (r) {
        PriceRange.h24 => c.xlmHistory24h,
        PriceRange.d7  => c.xlmHistory7,
        PriceRange.d30 => c.xlmHistory30,
        PriceRange.y1  => c.xlmHistory365,
      };
    } else {
      return switch (r) {
        PriceRange.h24 => c.usdcHistory24h,
        PriceRange.d7  => c.usdcHistory7,
        PriceRange.d30 => c.usdcHistory30,
        PriceRange.y1  => c.usdcHistory365,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat("#,##0.00");

    // streams / prices based on selected token
    final priceStream   = isXLM ? currency.xlmPriceStream : currency.usdcPriceStream;
    final lastPrice     = isXLM ? currency.xlmRate        : currency.usdcRate;
    final oneTokenFiat  = isXLM ? currency.xlmToFiat(1)   : currency.usdcToFiat(1);

    // selected balances & history
    final double tokenBalance = isXLM ? widget.xlmBalance : widget.usdcBalance;
    final double balanceFiat  = isXLM ? currency.xlmToFiat(tokenBalance) : currency.usdcToFiat(tokenBalance);

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
                  Tab(text: 'XLM'),
                  Tab(text: 'USDC'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<double>(
        stream: priceStream,
        builder: (context, snapshot) {
          final _ = snapshot.data ?? lastPrice; // triggers rebuilds
          final series = _historyFor(currency, isXLM: isXLM, r: _selected);

          final changePct = pctChangeFromSeries(series);
          final changeUp = changePct >= 0;
          final changeColor = changeUp ? Colors.green : Colors.red;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Price header
              PriceHeader(
                token: currentToken,
                oneTokenInFiat: oneTokenFiat,
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
                      Text(
                        "Tap to enlarge QR",
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
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
                        isXLM
                            ? "Send only XLM (native Stellar coin) to this address. Sending other networks or assets may result in permanent loss."
                            : "Send only USDC on the Stellar network to this address. The receiver must have a USDC trustline to accept funds.",
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
                Text(
                  "Receive $currentToken",
                  style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                ),
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
