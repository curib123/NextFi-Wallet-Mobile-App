import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Components/SnackBar.dart';

class ReceiveScreen extends StatefulWidget {
  final String address;
  final String token; // "TRX" or "USDT"
  final double balance;

  const ReceiveScreen({
    super.key,
    required this.address,
    required this.token,
    required this.balance,
  });

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  // Range options (days) for price change + chart
  static const _ranges = <String, int>{
    '24H': 1,
    '7D': 7,
    '30D': 30,
    '1Y': 365,
  };

  String _selectedRange = '24H';

  double _computeChangePct(List<double> history, int days) {
    if (history.isEmpty || days <= 0) return 0.0;
    // Need at least 2 points to compute change
    if (history.length < 2) return 0.0;

    // Compare the last point to the point N days back, or the earliest if insufficient
    final last = history.last;
    final idx = math.max(0, history.length - 1 - days);
    final ref = history[idx];
    if (ref <= 0) return 0.0;
    return ((last / ref) - 1.0) * 100.0;
  }

  List<double> _sliceForRange(List<double> history, int days) {
    if (history.isEmpty) return history;
    final start = math.max(0, history.length - (days + 1));
    return history.sublist(start);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = Provider.of<CurrencyProvider>(context, listen: true);

    final isTRX = widget.token.toUpperCase() == 'TRX';
    final fiatFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final numFmt = NumberFormat("#,##0.00");

    // pick stream & history by token
    final priceStream = isTRX ? currency.trxPriceStream : currency.usdtPriceStream;
    final history = isTRX ? currency.trxHistory : currency.usdtHistory;

    final selectedDays = _ranges[_selectedRange]!;
    final changePct = _computeChangePct(history, selectedDays);
    final changeUp = changePct >= 0;
    final changeColor = changeUp ? Colors.green : Colors.red;
    final changeIcon = changeUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight;

    // last price (fallback to current rate)
    final lastPrice = (isTRX ? currency.trxRate : currency.usdtRate);
    final oneTokenInFiat = isTRX ? currency.trxToFiat(1) : currency.usdtToFiat(1);

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
            Text(
              "Receive",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Copy address",
            icon: Icon(LucideIcons.copy, color: colors.textPrimary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.address));
              HapticFeedback.lightImpact();
              showFloatingSnackBar(context, message: "Address copied", type: SnackBarType.success);
            },
          ),
        ],
      ),
      body: StreamBuilder<double>(
        stream: priceStream,
        builder: (context, snapshot) {
          // live price if available
          final livePrice = snapshot.data ?? lastPrice;

          // history slice for chart
          final chartHistory = _sliceForRange(history, selectedDays);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ===== Price row with change pill =====
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
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
                          Text(
                            "${changeUp ? '+' : ''}${changePct.toStringAsFixed(2)}%",
                            style: TextStyle(
                              color: changeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedRange,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ===== Range selector =====
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ranges.keys.map((label) {
                  final selected = _selectedRange == label;
                  return ChoiceChip(
                    label: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedRange = label),
                    backgroundColor: colors.surface,
                    selectedColor: colors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: selected ? colors.primary : colors.textSecondary,
                    ),
                    side: BorderSide(
                      color: selected ? colors.primary.withOpacity(0.35) : colors.primary.withOpacity(0.15),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ===== Chart =====
              Container(
                height: 180,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.08)),
                ),
                child: (chartHistory.isEmpty || chartHistory.length < 2)
                    ? Center(child: CircularProgressIndicator(color: colors.primary))
                    : LineChart(
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
                        getTooltipItems: (touchedSpots) => touchedSpots
                            .map((s) => LineTooltipItem(
                          fiatFmt.format(s.y),
                          TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ))
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        spots: [
                          for (int i = 0; i < chartHistory.length; i++)
                            FlSpot(i.toDouble(), chartHistory[i]),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            changeColor,
                            changeColor.withOpacity(0.55),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [changeColor.withOpacity(0.18), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isLast = index == chartHistory.length - 1;
                            return FlDotCirclePainter(
                              radius: isLast ? 3.6 : 0,
                              color: isLast ? changeColor : Colors.transparent,
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
              ),
              const SizedBox(height: 24),

              // ===== QR Code (tap to enlarge) =====
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
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== Address Card =====
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

              // ===== Balance Card (token + fiat) =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "${numFmt.format(widget.balance)} ${widget.token.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "≈ ${fiatFmt.format(isTRX ? currency.trxToFiat(widget.balance) : currency.usdtToFiat(widget.balance))}",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Current balance",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ===== Safety Notice (TRON network) =====
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
                        "Send only ${widget.token.toUpperCase()} on TRON (TRC20) to this address. "
                            "Sending other networks or tokens may result in permanent loss.",
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.28,
                        ),
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
                  "Receive ${widget.token.toUpperCase()}",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
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
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.2,
                  ),
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
          Icon(
            token.toUpperCase() == 'TRX' ? LucideIcons.sparkle : LucideIcons.banknote,
            size: 14,
            color: colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            token.toUpperCase(),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
