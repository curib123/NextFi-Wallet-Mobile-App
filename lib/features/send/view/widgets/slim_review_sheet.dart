import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/transactions/view/widgets/asset_logo.dart';

class SlimReviewSheet extends StatelessWidget {
  const SlimReviewSheet({
    super.key,
    required this.tokenStr,
    required this.sender,
    required this.to,
    required this.recipientGets,
    required this.txFeeXlm,
    required this.netFeeXlm,
    required this.extraLabel,
    required this.extraValue,
    required this.onCancel,
    required this.onConfirm,
  });

  final String tokenStr, sender, to, recipientGets, txFeeXlm, netFeeXlm, extraLabel, extraValue;
  final VoidCallback onCancel, onConfirm;

  TableRow _kv(BuildContext context, String k, String v, {bool mono = false}) {
    final c = AppColor.of(context);
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: SelectableText(
        v, textAlign: TextAlign.right, maxLines: 2,
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontFamily: mono ? 'monospace' : null, fontSize: 13, height: 1.15),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Column(children: [
      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 6), decoration: BoxDecoration(color: c.primary.withOpacity(0.18), borderRadius: BorderRadius.circular(999)))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Text('Review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: c.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.primary.withOpacity(0.14))),
            child: Row(children: [AssetLogo(asset: tokenStr, size: 14), const SizedBox(width: 6), Text(tokenStr, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12))]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.12))),
          child: Row(children: [
            Icon(LucideIcons.badgeDollarSign, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text('Recipient receives', style: TextStyle(color: c.textSecondary, fontSize: 12))),
            Text('$recipientGets $tokenStr', textAlign: TextAlign.right, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontFamily: 'monospace', fontSize: 13.5)),
          ]),
        ),
      ),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.10))),
              child: Table(columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()}, children: [
                _kv(context, 'From', sender, mono: true),
                _kv(context, 'To', to, mono: true),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.10))),
              child: Table(columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()}, children: [
                _kv(context, 'Transaction fee', '$txFeeXlm XLM'),
                _kv(context, 'Network fee (est.)', '$netFeeXlm XLM'),
                _kv(context, extraLabel, extraValue),
              ]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Row(children: [
          Expanded(child: TextButton(onPressed: onCancel, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), foregroundColor: c.primary), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: onConfirm, icon: const Icon(LucideIcons.check, size: 18, color: Colors.white), label: const Text('Confirm'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), backgroundColor: c.primary, elevation: 0))),
        ]),
      ),
    ]);
  }
}
