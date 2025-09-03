// lib/Screen/WalletHomeScreenWidgets/asset_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Helper/AppColor.dart';

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.colors,
    required this.assets,
    required this.logos,
    required this.trxBalance,
    required this.usdtBalance,
    this.loading = false,
    this.onRefresh,
  });

  final AppColor colors;
  final List<AssetModel> assets;
  final Map<String, String> logos;
  final double trxBalance;   // passed from Home
  final double usdtBalance;  // passed from Home
  final bool loading;
  final Future<void> Function()? onRefresh; // optional pull-to-refresh

  double _balanceFor(AssetModel a) {
    final sym = a.symbol.toUpperCase();
    if (sym == 'TRX') return trxBalance;
    if (sym == 'USDT') return usdtBalance;
    return 0.0;
  }

  double _fiatFor(BuildContext ctx, AssetModel a) {
    final sym = a.symbol.toUpperCase();
    final cur = ctx.read<CurrencyProvider>();
    if (sym == 'TRX')  return cur.trxToFiat(trxBalance);
    if (sym == 'USDT') return cur.usdtToFiat(usdtBalance);
    return 0.0;
    // If you add more assets later, add conversion here.
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = context.watch<CurrencyProvider>().fiat.toUpperCase();

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
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final a = assets[index];
        final bal = _balanceFor(a);
        final fiat = _fiatFor(context, a);
        final pct  = a.priceChangePercent24h ?? 0.0;
        final logoUrl = logos[a.id];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _logo(logoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    const SizedBox(height: 2),
                    Text("$bal ${a.symbol}", style: TextStyle(color: colors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.simpleCurrency(name: currencyCode).format(fiat),
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  _pctBadge(pct),
                ],
              ),
            ],
          ),
        );
      },
    );

    return onRefresh != null
        ? RefreshIndicator(
      onRefresh: onRefresh!,
      color: colors.primary,
      child: listView,
    )
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
        loadingBuilder: (ctx, child, progress) =>
        progress == null ? child : SizedBox(width: size, height: size, child: const Center(child: SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth: 2)))),
      ),
    );
  }

  Widget _logoFallback(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: colors.border.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.image_not_supported, size: size * 0.6, color: colors.textSecondary.withOpacity(0.6)),
    );
  }

  Widget _pctBadge(double pct) {
    final positive = pct >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: positive ? Colors.green : Colors.red, size: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Shimmer.fromColors(
        baseColor: colors.border.withOpacity(0.30),
        highlightColor: colors.border.withOpacity(0.12),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
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
