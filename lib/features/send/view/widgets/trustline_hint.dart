import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/send/view_model/send_vm.dart';
import 'package:provider/provider.dart';

class TrustlineHint extends StatelessWidget {
  const TrustlineHint({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<SendVM>();
    if (vm.isXlm) return const SizedBox.shrink();
    if (vm.to.trim().isEmpty) return const SizedBox.shrink();

    if (vm.checking) {
      return Row(children: [
        SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
        const SizedBox(width: 8),
        Text('Checking USDC trustline…', style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ]);
    }

    if (vm.destHasUsdcTL == false) {
      return Row(children: [
        Icon(LucideIcons.alertTriangle, size: 14, color: c.error),
        const SizedBox(width: 6),
        Expanded(child: Text('This address has no USDC trustline.', style: TextStyle(color: c.error, fontSize: 12), overflow: TextOverflow.ellipsis)),
      ]);
    }

    if (vm.destHasUsdcTL == true) {
      return Row(children: [
        Icon(LucideIcons.checkCircle, size: 14, color: c.success),
        const SizedBox(width: 6),
        Text('USDC trustline detected', style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ]);
    }

    return const SizedBox.shrink();
  }
}
