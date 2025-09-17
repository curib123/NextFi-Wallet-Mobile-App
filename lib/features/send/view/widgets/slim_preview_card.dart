import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/transactions/view/widgets/asset_logo.dart';

class SlimPreviewCard extends StatelessWidget {
  final bool isXLM;
  final String token;
  final double recipientGets;
  final double estNetworkFeeXlm; // kept for input, but combined in UI
  final double txFeeXlm;         // kept for input, but combined in UI
  final double? totalBudgetXlm;
  final double? needsXlmForFeesIfUsdc;

  const SlimPreviewCard({
    super.key,
    required this.isXLM,
    required this.token,
    required this.recipientGets,
    required this.estNetworkFeeXlm,
    required this.txFeeXlm,
    required this.totalBudgetXlm,
    required this.needsXlmForFeesIfUsdc,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final double estTxFeeCombined = (txFeeXlm) + (estNetworkFeeXlm);

    Widget tiny(String k, String v) => Row(children: [
      Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 12))),
      const SizedBox(width: 6),
      Text(v, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
    ]);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.10)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(LucideIcons.info, size: 14, color: c.textSecondary),
          const SizedBox(width: 6),
          Text('Preview', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const Spacer(),
          Row(children: [
            AssetLogo(asset: token, size: 14),
            const SizedBox(width: 6),
            Text(token, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5)),
          ]),
        ]),
        const SizedBox(height: 8),
        tiny('Recipient receives', '${recipientGets.toStringAsFixed(6)} $token'),
        const SizedBox(height: 4),
        // 🔁 Combined line replaces the two separate fee rows:
        tiny('Est. transaction fee', '${estTxFeeCombined.toStringAsFixed(7)} XLM'),
        if (isXLM && (totalBudgetXlm ?? 0) > 0) ...[
          const SizedBox(height: 4),
          tiny('Total budget (deducted)', '${(totalBudgetXlm!).toStringAsFixed(6)} XLM'),
        ],
        if (!isXLM) ...[
          const SizedBox(height: 4),
          tiny('XLM required for fees', '${(needsXlmForFeesIfUsdc ?? 0).toStringAsFixed(7)} XLM'),
        ],
      ]),
    );
  }
}
