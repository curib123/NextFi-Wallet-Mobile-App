import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';

/// Build Tron transaction history list
/// [transactions] = List<Map<String, dynamic>> parsed from TronGrid/Node API
/// [userAddress] = current wallet address (to know incoming/outgoing)
Widget buildTransactionHistory(AppColor colors, List<Map<String, dynamic>> transactions, String userAddress) {
  return ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: transactions.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final tx = transactions[index];
      final contract = tx['raw_data']?['contract']?[0];
      final type = contract?['type'] ?? '';
      final value = contract?['parameter']?['value'] ?? {};

      String from = value['owner_address'] ?? '';
      String to = value['to_address'] ?? '';
      String token = 'TRX';
      double amount = 0;

      // Handle TRX transfer
      if (type == 'TransferContract') {
        final rawAmt = value['amount'] ?? 0;
        amount = rawAmt / 1e6; // TRX has 6 decimals
      }

      // Handle TRC20 (basic placeholder)
      if (type == 'TriggerSmartContract') {
        token = 'USDT'; // could decode further
        amount = 0; // parsing hex needed
      }

      final isIncoming = to == userAddress;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Transaction Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${amount.toStringAsFixed(2)} $token',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isIncoming
                        ? 'From: $from\nTo: You'
                        : 'From: You\nTo: $to',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron Icon
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      );
    },
  );
}
