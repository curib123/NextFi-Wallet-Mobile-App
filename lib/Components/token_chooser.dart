import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Model/asset_model.dart';

Future<void> showTokenSelector(
    BuildContext context,
    String address,
    double trxBalance,
    double usdtBalance, {
      required Widget Function(String address, String token, double balance) screenBuilder,
      String title = "Select Token",
    }) async {
  final colors = AppColor.of(context);

  // Read once (no rebuilds needed here)
  final assetProv = context.read<AssetProvider>();
  final List<AssetModel> assets = assetProv.assets;
  final Map<String, String> logos = assetProv.logos;

  String? logoForSymbol(String symbol) {
    final sym = symbol.toUpperCase();
    final asset = assets.firstWhere(
          (a) => a.symbol.toUpperCase() == sym,
      orElse: () => AssetModel(id: '', name: '', symbol: ''),
    );
    if (asset.id.isEmpty) return null;
    return logos[asset.id];
  }

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

            // ===== TRX =====
            _buildTokenTile(
              context,
              colors,
              logoUrl: logoForSymbol('TRX'),
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

            // ===== USDT (TRC20) =====
            _buildTokenTile(
              context,
              colors,
              logoUrl: logoForSymbol('USDT'),
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
      required String? logoUrl,
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
          _logoView(logoUrl, colors),
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

Widget _logoView(String? url, AppColor colors, {double size = 32}) {
  if (url == null || url.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.18),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        LucideIcons.helpCircle,
        size: size * 0.6,
        color: colors.textSecondary.withOpacity(0.6),
      ),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 2),
    child: Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.border.withOpacity(0.18),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Icon(
          LucideIcons.helpCircle,
          size: size * 0.6,
          color: colors.textSecondary.withOpacity(0.6),
        ),
      ),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    ),
  );
}
