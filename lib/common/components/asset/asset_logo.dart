import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';

class AssetLogo extends StatelessWidget {
  final String keyOrSymbol; // e.g. 'XLM', 'USDC', 'stellar', 'usdc_stellar'
  final double size;
  final double? radius;

  const AssetLogo({
    super.key,
    required this.keyOrSymbol,
    this.size = 28,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final assetVM = context.watch<AssetVM>();
    final url = assetVM.logoFor(keyOrSymbol);
    final r = radius ?? (size / 2);

    // help the cache pick the right resolution
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (size * dpr).round();
    final cacheH = (size * dpr).round();

    Widget fallbackBadge() {
      final ch = keyOrSymbol.isNotEmpty ? keyOrSymbol[0].toUpperCase() : '?';
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: colors.textSecondary.withValues(alpha: .15)),
        ),
        child: Text(
          ch,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: cacheW,
        memCacheHeight: cacheH,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 120),

        placeholder: (_, __) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: colors.textSecondary.withValues(alpha: .10)),
          ),
          child: SizedBox(
            width: size * 0.45,
            height: size * 0.45,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colors.textSecondary.withValues(alpha: .35)),
            ),
          ),
        ),

        errorWidget: (_, __, ___) => fallbackBadge(),
      ),
    );
  }
}
