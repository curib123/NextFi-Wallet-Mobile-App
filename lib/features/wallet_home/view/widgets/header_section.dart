// lib/features/wallet_home/view/widgets/header_section.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'live_counting_balance.dart';

class HeaderSection extends StatefulWidget {
  const HeaderSection({
    super.key,
    required this.colors,
    required this.currencyFmt,
    required this.loadingBalances,
    required this.totalFiat,
    required this.lastBalancesAt,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
    required this.livePulse,
    required this.incomingStrip,
  });

  final AppColor colors;
  final NumberFormat currencyFmt;
  final bool loadingBalances;
  final double totalFiat;
  final DateTime? lastBalancesAt;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final AnimationController livePulse;
  final Widget incomingStrip;

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left: balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Total Balance', style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: widget.colors.textSecondary)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _hideBalance = !_hideBalance),
                      child: Icon(
                          _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: widget.colors.textSecondary, size: 18),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  LiveCountingBalance(
                    hidden: _hideBalance,
                    targetValue: widget.totalFiat.isFinite
                        ? widget.totalFiat
                        : 0.0,
                    fmt: widget.currencyFmt,
                    baseColor: widget.colors.textPrimary,
                    loading: widget.loadingBalances,
                    pulse: widget.livePulse,
                  ),
                  const SizedBox(height: 4),
                  _UpdatedAgoLabel(
                      last: widget.lastBalancesAt, colors: widget.colors),
                ],
              ),

              // right: swap
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.colors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 5),
                  elevation: 3,
                ),
                onPressed: widget.onSwap,
                child: const Row(
                  children: [
                    Icon(LucideIcons.shuffle, size: 22, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Swap', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton(
                widget.colors, Icons.send, 'Send', onTap: widget.onSend),
            _actionButton(widget.colors, Icons.call_received, 'Receive',
                onTap: widget.onReceive),
            _actionButton(widget.colors, LucideIcons.wallet, 'Deposit',
                onTap: () => debugPrint('Deposit')),
            _actionButton(widget.colors, Icons.arrow_upward, 'Withdraw',
                onTap: () => debugPrint('Withdraw')),
          ],
        ),
        const SizedBox(height: 20),
        widget.incomingStrip,
      ],
    );
  }

  Widget _actionButton(AppColor colors,
      IconData icon,
      String label, {
        bool gradient = false,
        required VoidCallback onTap, // <-- Added callback
      }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap, // <-- Handle tap
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient
                    ? LinearGradient(
                  colors: [colors.primary, colors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: gradient ? null : colors.primary.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16), // Circle size
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

  class _UpdatedAgoLabel extends StatefulWidget {
  const _UpdatedAgoLabel({required this.last, required this.colors});
  final DateTime? last;
  final AppColor colors;
  @override
  State<_UpdatedAgoLabel> createState() => _UpdatedAgoLabelState();
}

class _UpdatedAgoLabelState extends State<_UpdatedAgoLabel> {
  Timer? _tick;
  @override
  void initState() { super.initState(); _tick = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _tick?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.last == null) return const SizedBox.shrink();
    final s = DateTime.now().difference(widget.last!).inSeconds;
    return Text(s <= 1 ? 'Updated just now' : 'Updated ${s}s ago',
        style: TextStyle(fontSize: 11, color: widget.colors.textSecondary));
  }
}
