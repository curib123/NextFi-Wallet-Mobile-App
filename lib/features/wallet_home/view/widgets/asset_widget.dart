// lib/Screen/WalletHomeScreenWidgets/asset_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/modal/price_window.dart';
import 'package:next_fi/common/components/modal/reserve_balance.dart';
import 'package:next_fi/features/wallet_home/view/widgets/modern_asset_tile.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/features/receive/view/receive_screen.dart';
import 'package:next_fi/features/wallet_home/view/widgets/asset_guide_footer.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_home/model/wallet_home_state.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.colors,
    required this.assets,
    required this.logos,
    required this.xlmBalance,
    required this.usdcBalance,
    required this.address,
    required this.hasUsdcTrustline,
    this.loading = false,
    this.onRefresh,
    this.onItemTap,
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final double xlmBalance;
  final double usdcBalance;
  final String address;
  final bool loading;
  final Future<void> Function()? onRefresh;
  final Object? hasUsdcTrustline;
  final void Function(String token)? onItemTap;

  double _liveBalance(
    BuildContext ctx,
    String symbolUpper, {
    bool reactive = false,
  }) {
    WalletHomeVM? vm;
    try {
      vm = Provider.of<WalletHomeVM?>(ctx, listen: reactive);
    } catch (_) {
      vm = null;
    }

    if (vm != null) {
      try {
        final dynamic dvm = vm;
        if (symbolUpper == 'XLM') {
          final bx = (dvm?.state?.xlmBalance ?? dvm?.xlmBalance) as double?;
          if (bx != null) return bx;
        } else if (symbolUpper == 'USDC') {
          final bu = (dvm?.state?.usdcBalance ?? dvm?.usdcBalance) as double?;
          if (bu != null) return bu;
        }
      } catch (_) {}
    }
    return symbolUpper == 'XLM'
        ? xlmBalance
        : (symbolUpper == 'USDC' ? usdcBalance : 0.0);
  }

  double _fiatFor(CurrencyVM cur, String symbolUpper, double balance) {
    switch (symbolUpper) {
      case 'XLM':
        return cur.xlmToFiat(balance);
      case 'USDC':
        return cur.usdcToFiat(balance);
      default:
        return 0.0;
    }
  }

  double _coinPriceFor(CurrencyVM cur, String symbolUpper) {
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

  String _windowShortLabel(PriceWindow w) {
    switch (w) {
      case PriceWindow.h24:
        return '24H';
      case PriceWindow.d7:
        return '7D';
      case PriceWindow.d30:
        return '30D';
      case PriceWindow.y1:
        return '1Y';
    }
  }

  void _openReceive(BuildContext context, AssetModel a) {
    final t = a.symbol.toUpperCase();
    final token = (t == 'USDC') ? 'USDC' : 'XLM';

    if (onItemTap != null) {
      onItemTap!(token);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveScreen(
          address: address,
          xlmBalance: _liveBalance(context, 'XLM'),
          usdcBalance: _liveBalance(context, 'USDC'),
          initialToken: token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<CurrencyVM>();
    final currencyCode = cur.fiat.toUpperCase();
    final money = NumberFormat.simpleCurrency(name: currencyCode);

    // Get price window from WalletHomeVM
    final homeVM = context.watch<WalletHomeVM?>();
    final window = homeVM?.state.selectedWindow ?? PriceWindow.h24;

    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (ctx, __) => _shimmerTile(ctx),
      );
    }

    final listView = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: assets.length + 2, // +2 for horizontal controls row and footer
      itemBuilder: (context, index) {
        if (index == 0) {
          // Horizontal row with Price Window (left) and Reserve Balance (right)
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Price Window Selector - Left side
                  Expanded(
                    child: _PriceWindowSelector(
                      colors: colors,
                      selectedWindow: window,
                      windowLabel: _windowShortLabel(window),
                      onWindowChanged: (newWindow) {
                        homeVM?.setPriceWindow(newWindow);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reserve Balance Card - Right side
                  Expanded(
                    child: _ReserveBalanceCard(colors: colors, money: money),
                  ),
                ],
              ),
            ),
          );
        } else if (index <= assets.length) {
          final a = assets[index - 1];
          final balance = _liveBalance(
            context,
            a.symbol.toUpperCase(),
            reactive: true,
          );
          final pct = _pctFor(a, window);
          final coinPrice = _coinPriceFor(cur, a.symbol.toUpperCase());

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
              fiatNow: _fiatFor(cur, a.symbol.toUpperCase(), balance),
              priceDelta: _priceDeltaPerCoin(coinPriceNow: coinPrice, pct: pct),
              money: money,
              onTap: () => _openReceive(context, a),
              formatTokenAmount: formatTokenAmount,
              formatSignedMoney: _formatSignedMoney,
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: AssetGuideFooter(
              colors: AppColor.of(context),
              xlmBalance: _liveBalance(context, 'XLM', reactive: true),
              usdcBalance: _liveBalance(context, 'USDC', reactive: true),
            ),
          );
        }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color blockColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFE5E7EB);

    Widget block(double w, double h, {double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: blockColor,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE6E8EB),
      highlightColor: isDark
          ? const Color(0xFF242424)
          : const Color(0xFFF2F3F5),
      period: const Duration(milliseconds: 2000),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            /// Leading circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: blockColor,
                shape: BoxShape.circle,
              ),
            ),

            const SizedBox(width: 14),

            /// Text skeletons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(140, 14),
                  const SizedBox(height: 8),
                  block(100, 12),
                ],
              ),
            ),

            const SizedBox(width: 12),

            /// Right meta
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                block(60, 14),
                const SizedBox(height: 8),
                block(40, 12, r: 12),
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
  final void Function(PriceWindow)? onWindowChanged;

  const _PriceWindowSelector({
    required this.colors,
    required this.selectedWindow,
    required this.windowLabel,
    this.onWindowChanged,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          showPriceWindowModal(
            context,
            colors: widget.colors,
            selectedWindow: widget.selectedWindow,
            onWindowChanged: widget.onWindowChanged,
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
                  ? widget.colors.primary.withOpacity(0.3)
                  : widget.colors.border.withOpacity(isDark ? 0.1 : 0.08),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.colors.primary.withOpacity(0.1),
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
                              Colors.transparent,
                              widget.colors.primary.withOpacity(
                                _isHovered ? 0.2 : 0.12,
                              ),
                              Colors.transparent,
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
                      LucideIcons.trendingUp,
                      size: 16,
                      color: widget.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Price Window ${widget.windowLabel}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.2,
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
class _ReserveBalanceCard extends StatefulWidget {
  final AppColor colors;
  final NumberFormat money;

  const _ReserveBalanceCard({required this.colors, required this.money});

  @override
  State<_ReserveBalanceCard> createState() => _ReserveBalanceCardState();
}

class _ReserveBalanceCardState extends State<_ReserveBalanceCard>
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
    final vm = context.watch<WalletHomeVM?>();
    if (vm == null) return const SizedBox.shrink();

    final state = vm.state;
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
                  ? widget.colors.primary.withOpacity(0.3)
                  : widget.colors.border.withOpacity(isDark ? 0.1 : 0.08),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.colors.primary.withOpacity(0.1),
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
                              Colors.transparent,
                              widget.colors.textSecondary.withOpacity(
                                _isHovered ? 0.15 : 0.08,
                              ),
                              Colors.transparent,
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
                        'Reserve ${state.xlmTotalReserve.toStringAsFixed(1)} XLM',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.2,
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
