import 'package:flutter/material.dart';
import 'package:next_fi/core/models/asset_model.dart';

class TokenTabs extends StatelessWidget {
  const TokenTabs({
    super.key,
    required this.assets,
    required this.token,
    required this.onChanged,
  });
  final List<AssetModel> assets;
  final String token;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final items = assets;
    if (items.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((asset) {
            final assetKey = asset.id;
            final selected =
                assetKey.toLowerCase() == token.toLowerCase() ||
                asset.symbol.toLowerCase() == token.toLowerCase();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => onChanged(assetKey),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? c.primary.withValues(alpha: 0.14)
                        : c.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    asset.symbol.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: selected
                          ? c.primary
                          : c.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
