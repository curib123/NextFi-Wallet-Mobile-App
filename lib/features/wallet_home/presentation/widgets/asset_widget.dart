// lib/Screen/WalletHomeScreenWidgets/asset_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/modal/price_window.dart';
import 'package:next_fi/core/widgets/modal/reserve_balance.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/modern_asset_tile.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/features/receive/presentation/screens/receive_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/asset_guide_footer.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';
import 'package:next_fi/app/theme/app_color.dart';

class AssetWidget extends ConsumerWidget {
  const AssetWidget({
    super.key,
    required this.colors,
    required this.assets,
    required this.logos,
    required this.balancesByAssetId,
    required this.address,
    required this.hasUsdcTrustline,
    this.loading = false,
    this.onRefresh,
    this.onItemTap,
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final Map<String, double> balancesByAssetId;
  final String address;
  final bool loading;
  final Future<void> Function()? onRefresh;
  final Object? hasUsdcTrustline;
  final void Function(String token)? onItemTap;

  double _liveBalance(WalletHomeState? state, AssetModel asset) {
    if (state != null) {
      return state.balanceFor(asset.id);
    }
    return balancesByAssetId[asset.id] ?? 0.0;
  }

  double _fiatFor(CurrencyVM cur, AssetModel asset, double balance) {
    final symbolUpper = asset.symbol.toUpperCase();
    switch (symbolUpper) {
      case 'XLM':
        return cur.xlmToFiat(balance);
      case 'USDC':
        return cur.usdcToFiat(balance);
      default:
        return 0.0;
    }
  }

  double _coinPriceFor(CurrencyVM cur, AssetModel asset) {
    final symbolUpper = asset.symbol.toUpperCase();
    switch (symbolUpper) {
      case 'XLM':
        return cur.xlmToFiat(1.0);
      case 'USDC':
        return cur.usdcToFiat(1.0);
      default:
        return 0.0;
    }
  }

  double _pctFor(AssetModel a, PriceWindow window) {
    switch (window) {
      case PriceWindow.h24:
        return a.priceChangePercent24h;
      case PriceWindow.d7:
        return a.priceChangePercent7d;
      case PriceWindow.d30:
        return a.priceChangePercent30d;
      case PriceWindow.y1:
        return a.priceChangePercent1y;
    }
  }

  double _priceDeltaPerCoin({
    required double coinPriceNow,
    required double pct,
  }) {
    if (!pct.isFinite || !coinPriceNow.isFinite) return 0.0;
    final denom = 1 + (pct / 100.0);
    if (denom <= 0) return 0.0;
    final prev = coinPriceNow / denom;
    return coinPriceNow - prev;
  }

  List<double> _miniSeriesFor(
    CurrencyVM cur,
    AssetModel asset,
    PriceWindow window,
  ) {
    final symbolUpper = asset.symbol.toUpperCase();
    switch (symbolUpper) {
      case 'XLM':
        return switch (window) {
          PriceWindow.h24 => cur.xlmHistory24h,
          PriceWindow.d7 => cur.xlmHistory7,
          PriceWindow.d30 => cur.xlmHistory30,
          PriceWindow.y1 => cur.xlmHistory365,
        };
      case 'USDC':
        return switch (window) {
          PriceWindow.h24 => cur.usdcHistory24h,
          PriceWindow.d7 => cur.usdcHistory7,
          PriceWindow.d30 => cur.usdcHistory30,
          PriceWindow.y1 => cur.usdcHistory365,
        };
      default:
        return const <double>[];
    }
  }

  String formatTokenAmount(
    double v, {
    int bigMaxDecimals = 4,
    int smallMaxDecimals = 7,
    double tinyCutoff = 1e-7,
  }) {
    if (v == 0 || v.isNaN) return '0';
    if (v.abs() < tinyCutoff) return '< 0.0000001';

    if (v.abs() >= 1.0) {
      final fmt = NumberFormat('#,##0.${'#' * bigMaxDecimals}');
      return _trimZeros(fmt.format(v));
    } else {
      if (v.abs() < 0.01) {
        return v.toStringAsFixed(4);
      }
      final fmt = NumberFormat('0.${'#' * smallMaxDecimals}');
      return _trimZeros(fmt.format(v));
    }
  }

  String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  String _formatSignedMoney(NumberFormat money, double v) {
    final s = money.format(v.abs());
    return v >= 0 ? '+$s' : '-$s';
  }

  void _openReceive(
    BuildContext context,
    AssetModel a,
    WalletHomeState? homeState,
  ) {
    if (onItemTap != null) {
      onItemTap!(a.id);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveScreen(
          address: address,
          initialToken: a.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(currencyVmProvider);
    final currencyCode = cur.fiat.toUpperCase();
    final money = NumberFormat.simpleCurrency(name: currencyCode);

    final homeState = ref.watch(walletHomeVmProvider).state;
    final window = homeState.selectedWindow;

    if (loading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final shimmerBase = isDark
          ? colors.surface.withValues(alpha: 0.92)
          : colors.border.withValues(alpha: 0.42);
      final shimmerHighlight = isDark
          ? colors.border.withValues(alpha: 0.96)
          : colors.surface;

      return Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        direction: ShimmerDirection.ltr,
        period: const Duration(milliseconds: 1500),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (ctx, __) => _shimmerTile(ctx),
        ),
      );
    }

    final listView = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: assets.length + 1,
      itemBuilder: (context, index) {
        if (index < assets.length) {
          final a = assets[index];
          final balance = _liveBalance(homeState, a);
          final pct = _pctFor(a, window);
          final coinPrice = _coinPriceFor(cur, a);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ModernAssetTile(
              asset: a,
              colors: colors,
              logoUrl: logos[a.id],
              balance: balance,
              isNative: a.isNative,
              pct: pct,
              coinPriceNow: coinPrice,
              fiatNow: _fiatFor(cur, a, balance),
              priceDelta: _priceDeltaPerCoin(coinPriceNow: coinPrice, pct: pct),
              miniSeries: _miniSeriesFor(cur, a, window),
              money: money,
              onTap: () => _openReceive(context, a, homeState),
              formatTokenAmount: formatTokenAmount,
              formatSignedMoney: _formatSignedMoney,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: AssetGuideFooter(
            colors: AppColor.of(context),
            xlmBalance: balancesByAssetId['stellar'] ?? homeState.xlm,
            usdcBalance: balancesByAssetId['usdc_stellar'] ?? homeState.usdc,
          ),
        );
      },
    );

    return onRefresh != null
        ? RefreshIndicator(
            onRefresh: onRefresh!,
            color: colors.primary,
            strokeWidth: 2.5,
            displacement: 50,
            child: listView,
          )
        : listView;
  }

  Widget _shimmerTile(BuildContext context) {
    final palette = AppColor.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockColor = isDark
        ? palette.border.withValues(alpha: 0.9)
        : palette.textSecondary.withValues(alpha: 0.22);

    Widget block(double w, double h, {double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: blockColor,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? palette.surface.withValues(alpha: 0.55)
              : palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? palette.border.withValues(alpha: 0.7)
                : palette.border.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(140, 14),
                  const SizedBox(height: 8),
                  block(110, 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                block(72, 14),
                const SizedBox(height: 8),
                block(44, 12, r: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Price Window Selector Widget - with visible horizontal wave shimmer
class _PriceWindowSelector extends StatefulWidget {
  final AppColor colors;
  final PriceWindow selectedWindow;
  final String windowLabel;

  const _PriceWindowSelector({
    required this.colors,
    required this.selectedWindow,
    required this.windowLabel,
  });

  @override
  State<_PriceWindowSelector> createState() => _PriceWindowSelectorState();
}

class _PriceWindowSelectorState extends State<_PriceWindowSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPosition;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerLabel = widget.windowLabel.trim();
    final hasHeaderLabel = headerLabel.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          showPriceWindowModal(
            context,
            colors: widget.colors,
            selectedWindow: widget.selectedWindow,
            onWindowChanged: null,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? widget.colors.primary.withValues(alpha: 0.3)
                  : widget.colors.border.withValues(alpha: isDark ? 0.1 : 0.08),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.colors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Horizontal wave shimmer effect - always visible
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedBuilder(
                    animation: _shimmerPosition,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColor.of(context).surface,
                              widget.colors.primary.withValues(
                                alpha: _isHovered ? 0.2 : 0.12,
                              ),
                              AppColor.of(context).surface,
                            ],
                            stops: [
                              (_shimmerPosition.value - 0.3).clamp(0.0, 1.0),
                              _shimmerPosition.value.clamp(0.0, 1.0),
                              (_shimmerPosition.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (hasHeaderLabel)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.trendingUp,
                        size: 16,
                        color: widget.colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Wallet Value Trend - $headerLabel',
                          style: TextStyle(
                            fontSize: 12.6,
                            fontWeight: FontWeight.w700,
                            color: widget.colors.textPrimary,
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reserve Balance Card Widget with horizontal wave shimmer
class _ReserveBalanceCard extends ConsumerStatefulWidget {
  final AppColor colors;
  final NumberFormat money;

  const _ReserveBalanceCard({required this.colors, required this.money});

  @override
  ConsumerState<_ReserveBalanceCard> createState() =>
      _ReserveBalanceCardState();
}

class _ReserveBalanceCardState extends ConsumerState<_ReserveBalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPosition;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletHomeVmProvider).state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          showReserveBalanceModal(
            context,
            colors: widget.colors,
            money: widget.money,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? widget.colors.primary.withValues(alpha: 0.3)
                  : widget.colors.border.withValues(alpha: isDark ? 0.1 : 0.08),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.colors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Horizontal wave shimmer effect - always visible
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedBuilder(
                    animation: _shimmerPosition,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColor.of(context).surface,
                              widget.colors.textSecondary.withValues(
                                alpha: _isHovered ? 0.15 : 0.08,
                              ),
                              AppColor.of(context).surface,
                            ],
                            stops: [
                              (_shimmerPosition.value - 0.3).clamp(0.0, 1.0),
                              _shimmerPosition.value.clamp(0.0, 1.0),
                              (_shimmerPosition.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.lock,
                      color: widget.colors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network Reserve: ${state.xlmTotalReserve.toStringAsFixed(1)} XLM',
                        style: TextStyle(
                          fontSize: 12.6,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
