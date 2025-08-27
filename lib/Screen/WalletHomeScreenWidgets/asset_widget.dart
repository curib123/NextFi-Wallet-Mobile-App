import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Model/asset_model.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AssetWidget extends StatefulWidget {
  final AppColor colors;

  const AssetWidget({super.key, required this.colors});

  @override
  State<AssetWidget> createState() => _AssetWidgetState();
}

class _AssetWidgetState extends State<AssetWidget> {
  // Simple in-memory cache for successful logos
  final Map<String, String> _logoCache = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = context.read<AssetProvider>();
      provider.fetchLogos();
      provider.fetchPriceChangePercent();
    });
  }

  Widget _buildShimmerTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Shimmer.fromColors(
        baseColor: widget.colors.border.withOpacity(0.3),
        highlightColor: widget.colors.border.withOpacity(0.1),
        child: Row(
          children: [
            Container(width: 36, height: 36, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 16, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(width: 80, height: 14, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 60, height: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

// Helper to handle cached logo loading dynamically
  Widget _buildAssetLogo(AssetModel asset, String? logoUrl) {
    // Main logo widget with cache handling
    Widget mainLogo = _buildCachedLogo(asset.id, logoUrl, 36);

    return mainLogo;
  }

// Helper to handle cached logo loading dynamically
  Widget _buildCachedLogo(String id, String? url, double size) {
    if (_logoCache.containsKey(id)) {
      return Image.network(
        _logoCache[id]!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            _logoCache[id] = url;
            return child;
          }
          return SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
    }

    return SizedBox(width: size, height: size);
  }

  Widget _buildAssetTile(AssetModel asset, String? logoUrl, double fiatValue) {
    final formattedFiat = NumberFormat.simpleCurrency(
      name: context.read<CurrencyProvider>().fiat.toUpperCase(),
    ).format(fiatValue);

    final percent = asset.priceChangePercent24h ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildAssetLogo(asset, logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${asset.balance} ${asset.symbol}",
                  style: TextStyle(color: widget.colors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedFiat,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${percent.toStringAsFixed(2)}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: percent >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivateButton(List<AssetModel> assets, AppColor colors) {
    final trx = assets.firstWhere(
          (a) => a.symbol == "TRX",
      orElse: () => AssetModel(
        id: "tron",
        name: "Tron",
        symbol: "TRX",
        balance: 0,
        coingeckoId: "tron",
      ),
    );

    if (trx.balance > 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.surface,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => debugPrint("TRX balance is zero. Please deposit first."),
        child: const Center(
          child: Text(
            "Need TRX to Activate Wallet",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AssetProvider, CurrencyProvider>(
      builder: (context, assetProvider, currencyProvider, _) {
        final isDataReady = !assetProvider.loading &&
            assetProvider.logos.isNotEmpty &&
            assetProvider.assets.every((a) => a.priceChangePercent24h != null) &&
            !currencyProvider.loading;

        if (!isDataReady) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, __) => _buildShimmerTile(),
          );
        }

        final assets = assetProvider.assets;

        return Column(
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final asset = assets[index];
                final logoUrl = assetProvider.logos[asset.id];
                double fiatValue = asset.symbol == "USDT"
                    ? currencyProvider.usdtToFiat(asset.balance)
                    : asset.symbol == "TRX"
                    ? currencyProvider.trxToFiat(asset.balance)
                    : 0.0;
                return _buildAssetTile(asset, logoUrl, fiatValue);
              },
            ),
            _buildActivateButton(assets, widget.colors),
          ],
        );
      },
    );
  }
}
