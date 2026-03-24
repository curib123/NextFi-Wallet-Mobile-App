import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer_button.dart';
import 'package:next_fi/core/widgets/modal/wallet_switch_result.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/import_wallet/presentation/screens/import_wallet_screen.dart';
import 'package:next_fi/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/screens/seed_phrase_screen.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key, this.scaffoldKey});

  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColor.of(context);
    final walletName =
        ref.watch(walletHomeVmProvider).state.walletName ?? 'Default Wallet';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => AppDrawerButton(
              colors: colors,
              onTap: () => _openDrawer(ctx),
            ),
          ),
          const Spacer(),
          _WalletSwitcher(
            walletName: walletName,
            colors: colors,
            onTap: () => _handleWalletSwitch(context, ref),
          ),
          const Spacer(),
          _SettingsActionButton(
            colors: colors,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PortfolioScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    if (scaffoldKey != null) {
      scaffoldKey!.currentState?.openDrawer();
    } else {
      Scaffold.of(context).openDrawer();
    }
  }

  Future<void> _handleWalletSwitch(BuildContext context, WidgetRef ref) async {
    final activeId = await SeedStorage.getActiveWalletId();
    if (!context.mounted) return;

    final res = await showWalletSwitchSheet(
      context,
      currentActiveId: activeId,
      allowGenerate: true,
    );

    if (res == null || !context.mounted) return;

    if (res.importRequested) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportWalletScreen()),
      );
      if (!context.mounted) return;
      await ref.read(walletHomeVmProvider).boot();
      if (!context.mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Wallets updated.',
        type: SnackBarType.success,
      );
      return;
    }

    if (res.createNew) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeedPhraseScreen()),
      );
      if (!context.mounted) return;
      await ref.read(walletHomeVmProvider).boot();
      return;
    }

    final chosenId = res.chosenWalletId;
    if (chosenId != null && chosenId != activeId) {
      final ok = await ref.read(walletHomeVmProvider).switchTo(chosenId);
      if (!context.mounted) return;
      showFloatingSnackBar(
        context,
        message: ok ? 'Switched active wallet.' : 'Failed to switch wallet.',
        type: ok ? SnackBarType.success : SnackBarType.error,
      );
    }
  }
}

class _WalletSwitcher extends StatelessWidget {
  const _WalletSwitcher({
    required this.walletName,
    required this.colors,
    required this.onTap,
  });

  final String walletName;
  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = walletName.trim().isEmpty ? 'My Wallet' : walletName.trim();
    const subtitle = 'Active wallet';

    return Material(
      color: AppColor.of(context).surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary.withValues(alpha: 0.12),
                  colors.surface.withValues(alpha: 0.55),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.of(
                    context,
                  ).textPrimary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.wallet2,
                    size: 14,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.05,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronDown,
                  size: 17,
                  color: colors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.colors,
    required this.onTap,
  });

  final AppColor colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.border.withValues(alpha: 0.08),
        ),
        child: Icon(
          LucideIcons.pieChart,
          color: colors.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}
