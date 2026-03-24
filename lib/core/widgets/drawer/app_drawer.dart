import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/website_links/website_links_service.dart';
import 'package:next_fi/core/utils/link_opener.dart';
import 'package:next_fi/features/import_wallet/presentation/screens/import_wallet_screen.dart';
import 'package:next_fi/features/seed_phrases/presentation/screens/seed_phrase_screen.dart';
import 'package:next_fi/features/settings/presentation/screens/settings_screen.dart';
import 'package:next_fi/features/wallet_settings/presentation/screens/wallet_settings_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColor.of(context);
    final walletState = ref.watch(walletHomeVmProvider).state;
    final websiteLinks = ref.watch(websiteLinksProvider);
    final walletName = (walletState.walletName ?? '').trim();
    final address = (walletState.address ?? '').trim();

    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(
              colors: colors,
              walletName: walletName.isEmpty ? 'Active Wallet' : walletName,
              address: address,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  _DrawerTile(
                    colors: colors,
                    icon: LucideIcons.settings2,
                    title: 'Wallet Settings',
                    subtitle: 'Manage nickname, assets, and wallet preferences',
                    onTap: () => _push(
                      context,
                      const WalletScreenSettings(),
                    ),
                  ),
                  _DrawerTile(
                    colors: colors,
                    icon: LucideIcons.import,
                    title: 'Import Wallet',
                    subtitle: 'Add another wallet to this device',
                    onTap: () => _push(
                      context,
                      const ImportWalletScreen(),
                    ),
                  ),
                  _DrawerTile(
                    colors: colors,
                    icon: LucideIcons.plusCircle,
                    title: 'Create Wallet',
                    subtitle: 'Generate a new wallet and keep it locally',
                    onTap: () => _push(
                      context,
                      const SeedPhraseScreen(),
                    ),
                  ),
                  _DrawerTile(
                    colors: colors,
                    icon: LucideIcons.slidersHorizontal,
                    title: 'App Settings',
                    subtitle: 'Theme, language, and app-wide preferences',
                    onTap: () => _push(context, const SettingsScreen()),
                  ),
                  const SizedBox(height: 8),
                  _LinkSection(
                    colors: colors,
                    links: websiteLinks.maybeWhen(
                      data: (value) => value,
                      orElse: () => WebsiteLinksConfig.fallback,
                    ),
                    isRefreshing: websiteLinks.isLoading,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: FutureBuilder<String?>(
                future: SeedStorage.getActiveWalletId(),
                builder: (context, snapshot) {
                  final walletId = (snapshot.data ?? '').trim();
                  if (walletId.isEmpty) return const SizedBox.shrink();
                  return Text(
                    'Wallet ID: $walletId',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.colors,
    required this.links,
    required this.isRefreshing,
  });

  final AppColor colors;
  final WebsiteLinksConfig links;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.link,
                color: colors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Useful Links',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (isRefreshing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _LinkRow(
            colors: colors,
            title: 'Privacy Policy',
            onTap: () => LinkOpener.open(
              context,
              links.privacyPolicyUrl,
              fallbackLabel: 'Privacy Policy',
            ),
          ),
          _LinkRow(
            colors: colors,
            title: 'Terms and Conditions',
            onTap: () => LinkOpener.open(
              context,
              links.termsAndConditionsUrl,
              fallbackLabel: 'Terms and Conditions',
            ),
          ),
          _LinkRow(
            colors: colors,
            title: 'NextFi Website',
            onTap: () => LinkOpener.open(
              context,
              links.nextfiWebsiteUrl,
              fallbackLabel: 'NextFi Website',
            ),
          ),
          _LinkRow(
            colors: colors,
            title: 'Stellar Website',
            onTap: () => LinkOpener.open(
              context,
              links.stellarWebsiteUrl,
              fallbackLabel: 'Stellar Website',
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.colors,
    required this.title,
    required this.onTap,
  });

  final AppColor colors;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              LucideIcons.externalLink,
              color: colors.textSecondary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.colors,
    required this.walletName,
    required this.address,
  });

  final AppColor colors;
  final String walletName;
  final String address;

  @override
  Widget build(BuildContext context) {
    final shortAddress = address.isEmpty
        ? 'No wallet selected'
        : '${address.substring(0, 6)}...${address.substring(address.length - 6)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.18),
            colors.surface,
          ],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.wallet2,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            walletName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            shortAddress,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppColor colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: colors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
