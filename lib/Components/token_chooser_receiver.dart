import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';

Future<void> showTokenSelector(
    BuildContext context,
    String address,
    double trxBalance,
    double usdtBalance, {
      required Widget Function(String address, String token, double balance) screenBuilder,
      String title = "Select Token",
    }) async {
  final colors = AppColor.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ===== Option: TRX =====
            _buildTokenTile(
              context,
              colors,
              icon: LucideIcons.coins,
              token: "TRX",
              balance: trxBalance,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => screenBuilder(address, "TRX", trxBalance),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ===== Option: USDT (TRC20) =====
            _buildTokenTile(
              context,
              colors,
              icon: LucideIcons.dollarSign,
              token: "USDT (TRC20)",
              balance: usdtBalance,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => screenBuilder(address, "USDT", usdtBalance),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildTokenTile(
    BuildContext context,
    AppColor colors, {
      required IconData icon,
      required String token,
      required double balance,
      required VoidCallback onTap,
    }) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.primary.withOpacity(0.1),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Balance: ${balance.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: colors.textSecondary),
        ],
      ),
    ),
  );
}
