import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/offers/presentation/screens/market_offers_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/verification_flow_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/portfolio_overview_section.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColor.of(context);
    final currency = ref.watch(currencyVmProvider);
    final assetsVm = ref.watch(assetVmProvider);
    final walletHome = ref.watch(walletHomeVmProvider);
    final portfolio = ref.watch(portfolioVmProvider);
    final liveAssets = assetsVm.assets;
    final totalFiat = _portfolioFiatTotal(
      currency: currency,
      assets: liveAssets,
      balancesByAssetId: walletHome.state.balancesByAssetId,
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.textPrimary,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio',
              style: AppFonts.title(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Wallet-scoped history and allocation',
              style: AppFonts.body(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () => ref.read(portfolioVmProvider).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: _WalletInfoStrip(
                    colors: colors,
                    walletLabel: portfolio.state.walletLabel,
                    walletAddress: portfolio.state.activeWalletAddress,
                    liveTotalFiat: totalFiat,
                    currency: currency,
                    assetCount: _activeAssetCount(
                      liveAssets,
                      walletHome.state.balancesByAssetId,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: PortfolioOverviewSection(
                    colors: colors,
                    state: portfolio.state,
                    currency: currency,
                    liveTotalFiat: totalFiat,
                    liveAssets: liveAssets,
                    balancesByAssetId: walletHome.state.balancesByAssetId,
                    onSend: () => ref.read(walletHomeVmProvider).onSendPressed(),
                    onReceive: () =>
                        ref.read(walletHomeVmProvider).onReceivePressed(),
                    onSwap: () => ref.read(walletHomeVmProvider).onSwapPressed(),
                    onP2P: () => _openP2PMarketplace(context, ref),
                    onRetry: () => ref.read(portfolioVmProvider).refresh(),
                    onRangeChanged: (range) =>
                        ref.read(portfolioVmProvider).setRange(range),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _activeAssetCount(
    List<AssetModel> assets,
    Map<String, double> balancesByAssetId,
  ) {
    var count = 0;
    for (final asset in assets) {
      if ((balancesByAssetId[asset.id] ?? 0) > 0) count++;
    }
    return count;
  }

  static double _portfolioFiatTotal({
    required CurrencyVM currency,
    required List<AssetModel> assets,
    required Map<String, double> balancesByAssetId,
  }) {
    var total = 0.0;
    for (final asset in assets) {
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      if (balance <= 0) continue;
      total += currency.assetAmountToFiat(asset, balance);
    }
    return total.isFinite ? total : 0.0;
  }

  Future<void> _openP2PMarketplace(BuildContext context, WidgetRef ref) async {
    final allowed = await _ensureVerifiedForTradeAccess(context, ref);
    if (!allowed || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MarketOffersScreen(initialType: OfferType.sell),
      ),
    );
  }

  Future<bool> _ensureVerifiedForTradeAccess(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final allowed = await ref.read(walletHomeVmProvider).hasTradeAccess();
      if (allowed) return true;
    } catch (_) {}

    if (!context.mounted) return false;
    showFloatingSnackBar(
      context,
      message: 'Verification READY is required for trades',
      type: SnackBarType.warning,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerificationFlowScreen()),
    );
    return false;
  }
}

class _WalletInfoStrip extends StatelessWidget {
  const _WalletInfoStrip({
    required this.colors,
    required this.walletLabel,
    required this.walletAddress,
    required this.liveTotalFiat,
    required this.currency,
    required this.assetCount,
  });

  final AppColor colors;
  final String? walletLabel;
  final String? walletAddress;
  final double liveTotalFiat;
  final CurrencyVM currency;
  final int assetCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: 0.98),
            colors.surfaceRaised.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wallet2,
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
                      walletLabel?.trim().isNotEmpty == true
                          ? walletLabel!.trim()
                          : 'Active wallet',
                      style: AppFonts.title(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _shortAddress(walletAddress),
                      style: AppFonts.body(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  colors: colors,
                  label: 'Live balance',
                  value: currency.formatFiat(liveTotalFiat),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  colors: colors,
                  label: 'Active assets',
                  value: '$assetCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortAddress(String? address) {
    final value = (address ?? '').trim();
    if (value.isEmpty) return 'Wallet address unavailable';
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.colors,
    required this.label,
    required this.value,
  });

  final AppColor colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.label(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.body(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
