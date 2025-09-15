import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';


Future<void> showTokenSelector(
    BuildContext context,
    String address,
    double xlmBalance,
    double usdcBalance, {
      required Widget Function(String address, String token, double balance) screenBuilder,
      String title = 'Select Asset',
    }) async {
  final colors = AppColor.of(context);

  // Read once (no rebuilds needed here)
  final assetProv = context.read<AssetVM>();
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

            // ===== XLM (native) =====
            _buildTokenTile(
              context,
              colors,
              logoUrl: logoForSymbol('XLM'),
              token: 'XLM',
              subtitle: 'Stellar Lumens (native)',
              balance: xlmBalance,
              icon: LucideIcons.star,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => screenBuilder(address, 'XLM', xlmBalance),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ===== USDC (credit) =====
            _buildTokenTile(
              context,
              colors,
              logoUrl: logoForSymbol('USDC'),
              token: 'USDC',
              subtitle: 'USDC (Stellar asset)',
              balance: usdcBalance,
              icon: LucideIcons.banknote,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => screenBuilder(address, 'USDC', usdcBalance),
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
      String? subtitle,
      required double balance,
      required IconData icon,
      required VoidCallback onTap,
    }) {
  String _num(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

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
          _logoView(logoUrl, colors, icon: icon),
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
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Balance: ${_num(balance)}',
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

Widget _logoView(String? url, AppColor colors, {double size = 32, IconData? icon}) {
  if (url == null || url.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.border.withOpacity(0.18),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        icon ?? LucideIcons.helpCircle,
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
          icon ?? LucideIcons.helpCircle,
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
