// lib/Screen/WalletHomeScreenWidgets/asset_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/reusable_model/asset_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/token_chooser.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
import 'package:next_fi/features/receive/view/receive_screen.dart';
import 'package:next_fi/features/send/view/send_screen.dart';
import 'package:next_fi/features/wallet_home/view/widgets/asset_guide_footer.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

enum PriceWindow { h24, d7, d30, y1 }

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
    this.window = PriceWindow.h24,
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
  final PriceWindow window;
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

  double _pctFor(AssetModel a) {
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

  Future<void> _openSendSelector(BuildContext context, AssetModel a) async {
    final addr = address.trim();
    if (addr.isEmpty) {
      showFloatingSnackBar(
        context,
        message: 'Wallet not ready',
        type: SnackBarType.warning,
      );
      return;
    }

    WalletHomeVM? homeVm;
    try {
      homeVm = context.read<WalletHomeVM?>();
    } catch (_) {
      homeVm = null;
    }

    final sym = a.symbol.toUpperCase();
    final defaultToken = (sym == 'USDC') ? 'USDC' : 'XLM';
    final xlmBal = _liveBalance(context, 'XLM');
    final usdcBal = _liveBalance(context, 'USDC');

    try {
      await showTokenSelector(
        context,
        addr,
        xlmBal,
        usdcBal,
        title: 'Select Coin',
        screenBuilder: (address, token, balance) => SendScreen(
          address: address,
          token: token,
          balance: balance,
          autoOpenScanner: true,
        ),
      );
    } catch (e) {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => SendScreen(
            address: addr,
            token: defaultToken,
            balance: defaultToken == 'USDC' ? usdcBal : xlmBal,
            autoOpenScanner: true,
          ),
        ),
      );
    } finally {
      try {
        await homeVm?.refresh(force: true);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<CurrencyVM>();
    final currencyCode = cur.fiat.toUpperCase();
    final money = NumberFormat.simpleCurrency(name: currencyCode);

    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, __) => _shimmerTile(ctx),
      );
    }

    final listView = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      itemCount: assets.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < assets.length) {
          final a = assets[index];
          return _AssetTile(
            asset: a,
            colors: colors,
            logoUrl: logos[a.id],
            balance: _liveBalance(context, a.symbol.toUpperCase(), reactive: true),
            pct: _pctFor(a),
            coinPriceNow: _coinPriceFor(cur, a.symbol.toUpperCase()),
            fiatNow: _fiatFor(cur, a.symbol.toUpperCase(), _liveBalance(context, a.symbol.toUpperCase(), reactive: true)),
            priceDelta: _priceDeltaPerCoin(
              coinPriceNow: _coinPriceFor(cur, a.symbol.toUpperCase()),
              pct: _pctFor(a),
            ),
            money: money,
            onTap: () => _openReceive(context, a),
            formatTokenAmount: formatTokenAmount,
            formatSignedMoney: _formatSignedMoney,
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

    final Widget scrollable = onRefresh != null
        ? RefreshIndicator(
      onRefresh: onRefresh!,
      color: colors.primary,
      strokeWidth: 2.5,
      displacement: 50,
      child: listView,
    )
        : listView;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Positioned.fill(child: scrollable),
        Positioned(
          right: 20,
          bottom: 20 + bottomInset,
          child: _AnimatedFAB(
            colors: colors,
            onPressed: () async {
              if (assets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No assets available')),
                );
                return;
              }
              final a = assets.firstWhere(
                    (x) => x.symbol.toUpperCase() == 'XLM',
                orElse: () => assets.first,
              );
              await _openSendSelector(context, a);
            },
          ),
        )
      ],
    );
  }

  Widget _shimmerTile(BuildContext context) {
    Widget block(double w, double h, {double r = 8}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    final sw = MediaQuery.of(context).size.width;
    final contentW = (sw - 140).clamp(180.0, sw);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border.withOpacity(isDark ? 0.1 : 0.08),
            width: 1,
          ),
        ),
        child: Shimmer.fromColors(
          baseColor: colors.border.withOpacity(isDark ? 0.15 : 0.12),
          highlightColor: colors.border.withOpacity(isDark ? 0.08 : 0.04),
          period: const Duration(milliseconds: 1500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(contentW * 0.35, 16, r: 6),
                      const SizedBox(height: 8),
                      block(contentW * 0.25, 14, r: 5),
                      const SizedBox(height: 6),
                      block(contentW * 0.28, 12, r: 5),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    block(80, 16, r: 6),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: block(48, 12, r: 4),
                    ),
                    const SizedBox(height: 6),
                    block(60, 12, r: 5),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends StatefulWidget {
  final AssetModel asset;
  final AppColor colors;
  final String? logoUrl;
  final double balance;
  final double pct;
  final double coinPriceNow;
  final double fiatNow;
  final double priceDelta;
  final NumberFormat money;
  final VoidCallback onTap;
  final String Function(double) formatTokenAmount;
  final String Function(NumberFormat, double) formatSignedMoney;

  const _AssetTile({
    required this.asset,
    required this.colors,
    required this.logoUrl,
    required this.balance,
    required this.pct,
    required this.coinPriceNow,
    required this.fiatNow,
    required this.priceDelta,
    required this.money,
    required this.onTap,
    required this.formatTokenAmount,
    required this.formatSignedMoney,
  });

  @override
  State<_AssetTile> createState() => _AssetTileState();
}

class _AssetTileState extends State<_AssetTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isUp = widget.priceDelta >= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPressed
                    ? widget.colors.primary.withOpacity(0.3)
                    : widget.colors.border.withOpacity(isDark ? 0.1 : 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isPressed
                      ? widget.colors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: _isPressed ? 12 : 8,
                  offset: Offset(0, _isPressed ? 2 : 4),
                  spreadRadius: _isPressed ? 1 : 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildLogo(widget.logoUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.asset.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: widget.colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${widget.formatTokenAmount(widget.balance)} ${widget.asset.symbol}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: widget.colors.textSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.money.format(widget.coinPriceNow)} / ${widget.asset.symbol}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.colors.textSecondary.withOpacity(0.7),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.money.format(widget.fiatNow),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildPctBadge(widget.pct, isDark),
                      const SizedBox(height: 4),
                      Text(
                        widget.formatSignedMoney(widget.money, widget.priceDelta),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUp
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.colors.primary.withOpacity(0.15),
              widget.colors.primary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          LucideIcons.coins,
          size: 24,
          color: widget.colors.primary.withOpacity(0.5),
        ),
      );
    }

    return Hero(
      tag: 'asset_logo_${widget.asset.id}',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.colors.primary.withOpacity(0.15),
                    widget.colors.primary.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                LucideIcons.coins,
                size: 24,
                color: widget.colors.primary.withOpacity(0.5),
              ),
            ),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: widget.colors.border.withOpacity(0.1),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.colors.primary.withOpacity(0.3),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPctBadge(double pct, bool isDark) {
    final positive = pct >= 0;
    final bgColor = positive
        ? const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.12)
        : const Color(0xFFEF4444).withOpacity(isDark ? 0.15 : 0.12);
    final textColor = positive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            "${pct.abs().toStringAsFixed(2)}%",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedFAB extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onPressed;

  const _AnimatedFAB({
    required this.colors,
    required this.onPressed,
  });

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: RotationTransition(
          turns: _rotationAnimation,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.colors.primary,
                  widget.colors.primary.withOpacity(0.85),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.colors.primary.withOpacity(isDark ? 0.4 : 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: widget.colors.primary.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.scanLine,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}