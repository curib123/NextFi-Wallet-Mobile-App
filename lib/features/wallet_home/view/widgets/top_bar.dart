// lib/features/wallet_home/view/widgets/top_bar.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/wallet_creation/view/wallet_creation_screen.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/common/components/wallet_switch_result.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/tab_vm.dart';
import 'package:next_fi/Services/seed_storage.dart';


class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final walletName = vm.state.walletName ?? 'Default Wallet';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(LucideIcons.package, color: colors.textPrimary, size: 26),
          onPressed: () => context.read<TabProvider>().setTab(1),
          tooltip: 'Activity',
        ),
        GestureDetector(
          onTap: () async {
            final activeId = await SeedStorage.getActiveWalletId();
            final res = await showWalletSwitchSheet(
              context,
              currentActiveId: activeId,
              allowGenerate: true,
            );
            if (res == null) return;

            if (res.createNew) {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletCreationScreen()));
              if (!context.mounted) return;
              await context.read<WalletHomeVM>().boot();
              return;
            }

            final chosenId = res.chosenWalletId;
            if (chosenId != null && chosenId != activeId) {
              final ok = await context.read<WalletHomeVM>().switchTo(chosenId);
              if (!context.mounted) return;
              showFloatingSnackBar(context,
                message: ok ? 'Switched active wallet.' : 'Failed to switch wallet.',
                type: ok ? SnackBarType.success : SnackBarType.error,
              );
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(walletName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 18, color: colors.textPrimary),
            ],
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 26),
          onPressed: () => context.read<TabProvider>().setTab(3),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}
