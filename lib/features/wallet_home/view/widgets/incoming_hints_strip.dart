import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/wallet_home/view/widgets/incoming_payment_hint.dart';
import 'package:next_fi/features/wallet_home/model/wallet_home_state.dart';

/// Shows up to 2 latest incoming hint cards with smooth animations
class IncomingHintsStrip extends StatelessWidget {
  const IncomingHintsStrip({
    super.key,
    required this.colors,
    required this.stellarAddress,
    required this.incomingHints,
    required this.onAcknowledge,
    this.walletState,
  });

  final AppColor colors;
  final String stellarAddress;
  final List<Map<String, dynamic>> incomingHints;
  final void Function(Map<String, dynamic> tx) onAcknowledge;
  final WalletHomeState? walletState;

  @override
  Widget build(BuildContext context) {
    if (incomingHints.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
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