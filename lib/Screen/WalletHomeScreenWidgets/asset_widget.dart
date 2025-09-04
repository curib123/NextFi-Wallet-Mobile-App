import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/receive_screen.dart'; // <-- ensure path is correct

enum PriceWindow { h24, d7, d30, y1 }

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.colors,
    required this.assets,
    required this.logos,
    required this.trxBalance,
    required this.usdtBalance,
    required this.address,                 // NEW: needed to open ReceiveScreen
    this.loading = false,
    this.onRefresh,
    this.window = PriceWindow.h24,
    this.onItemTap,                        // NEW: optional override
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final double trxBalance;
  final double usdtBalance;
  final String address;                    // NEW
  final bool loading;
  final Future<void> Function()? onRefresh;
  final PriceWindow window;

  /// Optional override if you want to handle navigation yourself.
  /// Receives the token string ('TRX' or 'USDT') that was tapped.
  final void Function(String token)? onItemTap; // NEW

  double _balanceFor(AssetModel a) {
    switch (a.symbol.toUpperCase()) {
      case 'TRX':
        return trxBalance;
      case 'USDT':
        return usdtBalance;
      default:
        return 0.0;
    }
  }

  double _fiatFor(BuildContext ctx, AssetModel a) {
    final cur = ctx.read<CurrencyProvider>();
    switch (a.symbol.toUpperCase()) {
      case 'TRX':
        return cur.trxToFiat(trxBalance);
      case 'USDT':
        return cur.usdtToFiat(usdtBalance);
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

  void _openReceive(BuildContext context, AssetModel a) {
    final t = a.symbol.toUpperCase();
    final token = (t == 'USDT') ? 'USDT' : 'TRX'; // default to TRX if unknown

    if (onItemTap != null) {
      onItemTap!(token);
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReceiveScreen(
        address: address,
        trxBalance: trxBalance,
        usdtBalance: usdtBalance,
        initialToken: token, // initial tab based on tapped tile
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = context.watch<CurrencyProvider>().fiat.toUpperCase();
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
      itemCount: assets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final a = assets[index];
        final bal = _balanceFor(a);
        final fiat = _fiatFor(context, a);
        final pct = _pctFor(a);
        final logoUrl = logos[a.id];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16,),
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
                          Text(a.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 2),
                          Text("$bal ${a.symbol}",
                              style: TextStyle(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money.format(fiat),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        _pctBadge(pct),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, color: colors.primary, child: listView)
        : listView;
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
        color: colors.border.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_not_supported,
          size: size * 0.6, color: colors.textSecondary.withOpacity(0.6)),
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
        baseColor: colors.border.withOpacity(0.30),
        highlightColor: colors.border.withOpacity(0.12),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 72, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
