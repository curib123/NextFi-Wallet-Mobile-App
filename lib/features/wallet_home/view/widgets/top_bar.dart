// lib/features/wallet_home/view/widgets/top_bar.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/settings/view/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/view/wallet_screen_settings.dart';
import 'package:next_fi/reusable_view_model/tab_vm.dart';
import 'package:next_fi/features/import_wallet/view/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/view/seed_phrase_screen.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/wallet_switch_result.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/Services/seed_storage.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'WW';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts.first[0];
      final last = parts.last[0];
      return (first + last).toUpperCase();
    } else {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : (w + 'W')).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final walletName = vm.state.walletName ?? 'Default Wallet';
    final initials = _initials(walletName);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Wallet "transparent" profile circle → Activity
        Tooltip(
          message: 'Activity',
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreenSettings()),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withOpacity(0.12), // translucent fill
                border: Border.all(
                  color: colors.primary.withOpacity(0.28), // subtle ring
                  width: 1,
                ),
              ),
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.primary,         // use primary for text
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),

        // Center: Wallet name + switcher
        GestureDetector(
          onTap: () async {
            final activeId = await SeedStorage.getActiveWalletId();
            final res = await showWalletSwitchSheet(
              context,
              currentActiveId: activeId,
              allowGenerate: true,
            );
            if (res == null) return;

            if (res.importRequested) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
              );
              if (!context.mounted) return;
              await context.read<WalletHomeVM>().boot();
              showFloatingSnackBar(context, message: 'Wallets updated.', type: SnackBarType.success);
              return;
            }

            if (res.createNew) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
              );
              if (!context.mounted) return;
              await context.read<WalletHomeVM>().boot();
              return;
            }

            final chosenId = res.chosenWalletId;
            if (chosenId != null && chosenId != activeId) {
              final ok = await context.read<WalletHomeVM>().switchTo(chosenId);
              if (!context.mounted) return;
              showFloatingSnackBar(
                context,
                message: ok ? 'Switched active wallet.' : 'Failed to switch wallet.',
                type: ok ? SnackBarType.success : SnackBarType.error,
              );
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                walletName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronDown, size: 18, color: colors.textPrimary),
            ],
          ),
        ),

        // Right: Settings
        IconButton(
          icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 26),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }
}
