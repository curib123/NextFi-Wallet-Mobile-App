import 'package:flutter/material.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/incoming_payment_hint.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';

class IncomingHintsStrip extends StatelessWidget {
  const IncomingHintsStrip({
    super.key,
    required this.colors,
    required this.stellarAddress,
    required this.incomingHints,
    required this.onAcknowledge,
    this.onActiveTradeTap,
    this.activeTradeCount = 0,
    this.walletState,
  });

  final AppColor colors;
  final String stellarAddress;
  final List<Map<String, dynamic>> incomingHints;
  final void Function(Map<String, dynamic> tx) onAcknowledge;
  final VoidCallback? onActiveTradeTap;
  final int activeTradeCount;
  final WalletHomeState? walletState;

  @override
  Widget build(BuildContext context) {
    if (incomingHints.isEmpty && activeTradeCount <= 0) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
          if (activeTradeCount > 0)
            activeTradeRoomHint(
              context,
              activeTradeCount: activeTradeCount,
              onTap: onActiveTradeTap,
            ),
          for (final tx in incomingHints.take(2))
            incomingPaymentHint(
              tx,
              stellarAddress,
              onAcknowledge: () => onAcknowledge(tx),
              walletState: walletState,
            ),
        ],
      ),
    );
  }
}
