import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/features/wallet_home/view/widgets/incoming_payment_hint.dart';

/// Shows up to 2 latest incoming hint cards.
class IncomingHintsStrip extends StatelessWidget {
  const IncomingHintsStrip({
    super.key,
    required this.colors,
    required this.stellarAddress,
    required this.incomingHints,
    required this.onAcknowledge,
  });

  final AppColor colors;
  final String stellarAddress;
  final List<Map<String, dynamic>> incomingHints;
  final void Function(Map<String, dynamic> tx) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    if (incomingHints.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final tx in incomingHints.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: incomingPaymentHint(
              tx,
              stellarAddress,
              onAcknowledge: () => onAcknowledge(tx),
            ),
          ),
      ],
    );
  }
}

