import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
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
      backgroundColor: colors.background,
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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: [
                  _SectionLabel(colors: colors, title: 'Wallet'),
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
                  const SizedBox(height: 14),
                  _SectionLabel(colors: colors, title: 'Links'),
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _AppMetaCard(colors: colors),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.colors, required this.title});

  final AppColor colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.15,
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
          const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              LucideIcons.externalLink,
              color: colors.textSecondary.withValues(alpha: 0.9),
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
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.08),
            colors.surface,
          ],
          stops: const [0, 0.45, 1],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.66)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wallet2,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.radio, size: 12, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Active Wallet',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            walletName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border.withValues(alpha: 0.48)),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wallet-first identity and local multi-wallet access',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: colors.primary, size: 19),
                ),
                const SizedBox(width: 13),
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
                          fontSize: 12.1,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.arrowUpRight,
                    color: colors.textSecondary.withValues(alpha: 0.88),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMetaCard extends StatelessWidget {
  const _AppMetaCard({required this.colors});

  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final appName = (snapshot.data?.appName ?? 'NextFi Wallet').trim();
        final version = snapshot.hasData
            ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
            : 'Loading version...';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.sparkles,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      version,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
