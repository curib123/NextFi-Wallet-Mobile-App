// lib/Screen/receive_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Screen/price_chart_card.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';

class ReceiveScreen extends StatefulWidget {
  final String address;
  final double xlmBalance;
  final double usdcBalance;
  /// 'XLM' or 'USDC'
  final String initialToken;

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

class _ReceiveScreenState extends State<ReceiveScreen> {
  late bool _xlmSelected;

  @override
  void initState() {
    super.initState();
    _xlmSelected = widget.initialToken.toUpperCase() != 'USDC';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Receive',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Consumer<CurrencyProvider>(
        builder: (context, currency, _) {
          final fiat = currency.fiat.toUpperCase();
          final fiatFmt = NumberFormat.simpleCurrency(name: fiat);
          final numFmt = NumberFormat('#,##0.######');

          final isXLM = _xlmSelected;
          final token = isXLM ? 'XLM' : 'USDC';
          final tokenBalance = isXLM ? widget.xlmBalance : widget.usdcBalance;

          // 🔌 Live fiat price streams from the provider (no polling)
          final priceStream = isXLM ? currency.xlmPriceStream : currency.usdcPriceStream;
          final lastPrice   = isXLM ? currency.xlmRate        : currency.usdcRate;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Token switch (simple, clean, no TabController)
              _TokenSwitch(
                xlmSelected: _xlmSelected,
                onSelectXLM: () => setState(() => _xlmSelected = true),
                onSelectUSDC: () => setState(() => _xlmSelected = false),
                color: c,
              ),
              const SizedBox(height: 12),
              PriceChartCard(title:token ,token: token,),
              const SizedBox(height: 12),

              // QR card (tap to enlarge)
              GestureDetector(
                onTap: () => _showQrDialog(context, token),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.primary.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Scan to receive $token',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.white,
                          child: QrImageView(
                            data: widget.address,
                            version: QrVersions.auto,
                            size: 220,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to enlarge',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Address (monospace) + quick copy
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.wallet, size: 18, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        widget.address,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: Icon(LucideIcons.copy, size: 20, color: c.primary),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: widget.address));
                        HapticFeedback.lightImpact();
                        showFloatingSnackBar(
                          context,
                          message: 'Address copied',
                          type: SnackBarType.success,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safety note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _xlmSelected
                      ? 'Send only XLM (native Stellar) to this address. Sending other assets or from other networks may result in permanent loss.'
                      : 'Send only USDC on the Stellar network to this address. A USDC trustline is required to receive funds.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQrDialog(BuildContext context, String token) {
    final c = AppColor.of(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TokenPill(token: token, color: c),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white,
                  child: QrImageView(
                    data: widget.address,
                    version: QrVersions.auto,
                    size: 260,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.address,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
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
                        showFloatingSnackBar(
                          context,
                          message: 'Address copied',
                          type: SnackBarType.success,
                        );
                      },
                      icon: Icon(LucideIcons.copy, size: 18, color: c.primary),
                      label: Text(
                        'Copy',
                        style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.primary.withOpacity(0.35)),
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
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
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
      ),
    );
  }
}

/// Simple two-button switch (XLM / USDC) with clean styles.
class _TokenSwitch extends StatelessWidget {
  const _TokenSwitch({
    required this.xlmSelected,
    required this.onSelectXLM,
    required this.onSelectUSDC,
    required this.color,
  });

  final bool xlmSelected;
  final VoidCallback onSelectXLM;
  final VoidCallback onSelectUSDC;
  final AppColor color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentButton(
            label: 'XLM',
            selected: xlmSelected,
            onTap: onSelectXLM,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegmentButton(
            label: 'USDC',
            selected: !xlmSelected,
            onTap: onSelectUSDC,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColor color;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color.primary : color.primary.withOpacity(0.06);
    final fg = selected ? Colors.white : color.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.primary.withOpacity(selected ? 0.0 : 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal token pill (no external assets).
class _TokenPill extends StatelessWidget {
  const _TokenPill({required this.token, required this.color});
  final String token;
  final AppColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        token,
        style: TextStyle(
          color: color.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
