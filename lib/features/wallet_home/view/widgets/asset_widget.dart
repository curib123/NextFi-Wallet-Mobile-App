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
import 'package:next_fi/Helper/AppColor.dart';

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
    this.onItemTap, // optional override for LIST TILE taps only
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final double xlmBalance;
  final double usdcBalance;
  final String address; // wallet public address
  final bool loading;
  final Future<void> Function()? onRefresh;
  final PriceWindow window;
  final Object? hasUsdcTrustline;

  /// Optional override if you want to handle **list item taps** yourself.
  /// Receives the token string ('XLM' or 'USDC') that was tapped.
  /// NOTE: The FAB ignores this and always goes to **Send**.
  final void Function(String token)? onItemTap;

  // ────────────────────────────────────────────────────────────────────────────
  // Live balance taps (reactive for UI; non-reactive for event handlers)
  // ────────────────────────────────────────────────────────────────────────────
  double _liveBalance(
      BuildContext ctx,
      String symbolUpper, {
        bool reactive = false,
      }) {
    WalletHomeVM? vm;
    try {
      vm = Provider.of<WalletHomeVM?>(ctx, listen: reactive);
    } catch (_) {
      vm = null; // Provider may not be in tree; use props fallback
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

  // ────────────────────────────────────────────────────────────────────────────
  // Price & percent helpers
  // ────────────────────────────────────────────────────────────────────────────
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

  // Price per coin in selected fiat
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

  /// Absolute **price** change PER COIN (in fiat) for the selected window.
  /// Uses current price and % change to infer the previous price:
  /// prev = now / (1 + pct/100), delta = now - prev
  double _priceDeltaPerCoin({
    required double coinPriceNow,
    required double pct,
  }) {
    if (!pct.isFinite || !coinPriceNow.isFinite) return 0.0;
    final denom = 1 + (pct / 100.0); // guard -100%
    if (denom <= 0) return 0.0;
    final prev = coinPriceNow / denom;
    return coinPriceNow - prev; // signed
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Formatting helpers
  // ────────────────────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────────────────────
  // Navigation
  // ────────────────────────────────────────────────────────────────────────────

  // List-tile tap → Receive (unless overridden)
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
          xlmBalance: _liveBalance(context, 'XLM'), // non-reactive
          usdcBalance: _liveBalance(context, 'USDC'), // non-reactive
          initialToken: token,
        ),
      ),
    );
  }

  // FAB tap → Send (always). Intentionally ignores onItemTap.
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

    // Capture provider (nullable) BEFORE opening any sheets.
    WalletHomeVM? homeVm;
    try {
      homeVm = context.read<WalletHomeVM?>();
    } catch (_) {
      homeVm = null;
    }

    // Defaults / balances (non-reactive reads)
    final sym = a.symbol.toUpperCase();
    final defaultToken = (sym == 'USDC') ? 'USDC' : 'XLM';
    final xlmBal = _liveBalance(context, 'XLM');
    final usdcBal = _liveBalance(context, 'USDC');

    try {
      // Try the token chooser first
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
      // Fallback: push SendScreen directly via root navigator so it always shows
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
      // Refresh if the VM exists; don’t assume it’s provided.
      try {
        await homeVm?.refresh(force: true);
      } catch (_) {/* ignore */}
    }
  }

  @override
  Widget build(BuildContext context) {
    // PRICE real-time: watch CurrencyVM (notifies on price/fiat changes)
    final cur = context.watch<CurrencyVM>();
    final currencyCode = cur.fiat.toUpperCase();
    final money = NumberFormat.simpleCurrency(name: currencyCode);

    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, __) => _shimmerTile(),
      );
    }

    final listView = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: assets.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        if (index < assets.length) {
          final a = assets[index];
          final sym = a.symbol.toUpperCase();

          // BALANCE real-time: listen for rebuilds in UI
          final bal = _liveBalance(context, sym, reactive: true);

          // Compute fiat & per-coin price delta using **current** price and % change
          final pct = _pctFor(a);
          final coinPriceNow = _coinPriceFor(cur, sym);
          final fiatNow = _fiatFor(cur, sym, bal);

          // Price delta per coin (NOT multiplied by holdings)
          final priceDelta = _priceDeltaPerCoin(
            coinPriceNow: coinPriceNow,
            pct: pct,
          );
          final isUp = priceDelta >= 0;
          final logoUrl = logos[a.id];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openReceive(context, a),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      _logo(logoUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${formatTokenAmount(bal)} ${a.symbol}",
                              style: TextStyle(color: colors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${money.format(coinPriceNow)} / ${a.symbol}",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary.withOpacity(.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money.format(fiatNow),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _pctBadge(pct),
                          const SizedBox(height: 2),
                          // Real-time **price delta per coin** (NOT multiplied by holdings)
                          Text(
                            _formatSignedMoney(money, priceDelta),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isUp ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // ---- Guide footer (single, after all tiles) ----
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
      child: listView,
    )
        : listView;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Positioned.fill(child: scrollable),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: FloatingActionButton(
            heroTag: 'assets_scan_fab',
            tooltip: 'Scan to send',
            shape: const CircleBorder(),
            onPressed: () async {
              if (assets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No assets available')),
                );
                return;
              }

              // Prefer XLM; fallback to the first asset
              final a = assets.firstWhere(
                    (x) => x.symbol.toUpperCase() == 'XLM',
                orElse: () => assets.first,
              );

              await _openSendSelector(context, a); // non-reactive use
            },
            child: const Icon(LucideIcons.scanLine),
          ),
        )
      ],
    );
  }

  // --- small UI helpers ---

  Widget _logo(String? url, {double size = 36}) {
    if (url == null || url.isEmpty) return _logoFallback(size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _logoFallback(size),
        loadingBuilder: (ctx, child, progress) => progress == null
            ? child
            : SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.border.withOpacity(.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported,
        size: size * 0.6,
        color: colors.textSecondary.withOpacity(.6),
      ),
    );
  }

  Widget _pctBadge(double pct) {
    final positive = pct >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: positive ? Colors.green : Colors.red,
          size: 18,
        ),
        Text(
          "${pct.abs().toStringAsFixed(2)}%",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: positive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _shimmerTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Shimmer.fromColors(
        baseColor: colors.border.withOpacity(.30),
        highlightColor: colors.border.withOpacity(.12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 14, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 90, height: 12, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                    width: 110,
                    height: 10,
                    color: Colors.white,
                  ), // coin price line
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(width: 72, height: 14, color: Colors.white),
                const SizedBox(height: 6),
                Container(
                    width: 54,
                    height: 12,
                    color: Colors.white), // % badge stub
                const SizedBox(height: 6),
                Container(
                    width: 64,
                    height: 10,
                    color: Colors.white), // price delta stub
              ],
            ),
          ],
        ),
      ),
    );
  }
}
