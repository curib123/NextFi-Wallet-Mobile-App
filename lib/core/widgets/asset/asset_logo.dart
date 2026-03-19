import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/asset/asset_remote_image.dart';

class AssetLogo extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColor.of(context);
    final assetVM = ref.watch(assetVmProvider);
    final url = assetVM.logoFor(keyOrSymbol);
    final r = radius ?? (size / 2);

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
      child: AssetRemoteImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: Container(
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
        fallback: fallbackBadge(),
      ),
    );
  }
}

