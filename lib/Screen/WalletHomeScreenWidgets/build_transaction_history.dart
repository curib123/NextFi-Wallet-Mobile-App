// In WalletHomeScreenWidgets class (or a helper class)
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

Widget buildTransactionHistory(AppColor colors, List<PaymentOperationResponse> _transactionHistory) {
  return ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: _transactionHistory.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final tx = _transactionHistory[index];
      final amount = double.parse(tx.amount);
      final from = tx.sourceAccount;
      final to = tx.to;

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
                    '${amount.toStringAsFixed(2)} XLM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: $from\nTo: $to',
                    style:  TextStyle(
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