import 'package:flutter/material.dart';
import 'package:next_fi/Helper/AppColor.dart';
// If you have an AssetLogo widget elsewhere, import it here:
// import 'package:next_fi/Screen/WalletHomeScreenWidgets/asset_widget.dart' show AssetLogo;

class BalanceRow extends StatelessWidget {
  final double xlm, usdc;
  const BalanceRow({super.key, required this.xlm, required this.usdc});

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    String numFmt(double v) => v.toStringAsFixed(v >= 100 ? 2 : 4);

    Widget chip(String assetKey, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // If you have a logo widget, uncomment:
        // AssetLogo(asset: assetKey, size: 16),
        // const SizedBox(width: 6),
        Text('$assetKey: ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      ]),
    );

    return Row(children: [
      Expanded(child: chip('XLM', numFmt(xlm))),
      const SizedBox(width: 8),
      Expanded(child: chip('USDC', numFmt(usdc))),
    ]);
  }
}
