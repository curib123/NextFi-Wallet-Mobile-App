import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

Widget actionButton(AppColor colors, IconData icon, String label, {bool gradient = false}) {
  return Column(
    children: [
      Container(
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
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16), // Circle radius
          child: Icon(icon, color: Colors.white, size: 28),
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

// In WalletHomeScreen class (or a helper class)
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


Widget recipientList(AppColor colors) {
  return ListView.builder(
    itemCount: 10,
    itemBuilder: (context, index) {
      return recipientTile(
        colors: colors,
        recipientName: 'Recipient #$index',
        address: '0xABCDEF12345$index',
        onTap: () {
          // Handle tap event
        },
      );
    },
  );
}

Widget recipientTile({
  required AppColor colors,
  required String recipientName,
  required String address,
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: colors.surface.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primary.withOpacity(0.1),
        child: Icon(LucideIcons.user, color: colors.primary),
      ),
      title: Text(
        recipientName,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        address,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}