import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';

Future<void> showTokenSelector(
  BuildContext context,
  String address, {
  double Function(AssetModel asset)? balanceResolver,
  required Future<void> Function(String address, String token, double balance)
  onSelect,
  String title = 'Select Asset',
}) async {
  final assetVM = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(assetVmProvider);

  double balanceFor(AssetModel asset) {
    if (balanceResolver != null) {
      return balanceResolver(asset);
    }
    return 0.0;
  }

  Future<void> open(AssetModel asset) async {
    final balance = balanceFor(asset);
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await onSelect(address, asset.id, balance);
  }

  await showAppModalBottomSheet(
    context,
    builder: (_) => _TokenSelectorSheet(
      title: title,
      assets: assetVM.walletHomeAssets,
      allAssetCount: assetVM.assets.length,
      balanceFor: balanceFor,
      onSelect: open,
    ),
  );
}

class _TokenSelectorSheet extends ConsumerStatefulWidget {
  const _TokenSelectorSheet({
    required this.title,
    required this.assets,
    required this.allAssetCount,
    required this.balanceFor,
    required this.onSelect,
  });

  final String title;
  final List<AssetModel> assets;
  final int allAssetCount;
  final double Function(AssetModel) balanceFor;
  final Future<void> Function(AssetModel) onSelect;

  @override
  ConsumerState<_TokenSelectorSheet> createState() =>
      _TokenSelectorSheetState();
}

class _TokenSelectorSheetState extends ConsumerState<_TokenSelectorSheet> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final assets = ref.watch(assetVmProvider).walletHomeAssets;

    return AppModalBase(
      maxHeightFactor: 0.62,
      backgroundColor: colors.surface,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: widget.title,
            visibleAssetCount: assets.length,
            totalAssetCount: widget.allAssetCount,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: assets.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: assets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      return _SelectableTokenTile(
                        asset: asset,
                        balance: widget.balanceFor(asset),
                        onTap: () async {
                          await widget.onSelect(asset);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.visibleAssetCount,
    required this.totalAssetCount,
  });

  final String title;
  final int visibleAssetCount;
  final int totalAssetCount;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.12),
            colors.background.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.68)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: colors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.coins, color: colors.onPrimary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$visibleAssetCount visible | $totalAssetCount supported',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableTokenTile extends StatelessWidget {
  const _SelectableTokenTile({
    required this.asset,
    required this.balance,
    required this.onTap,
  });

  final AssetModel asset;
  final double balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              AssetLogo(keyOrSymbol: asset.id, size: 42, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol.toUpperCase(),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatBalance(balance),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    color: colors.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBalance(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1000) {
      return NumberFormat.compact().format(value);
    }
    if (value.abs() >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.coins, color: colors.textMuted, size: 28),
          const SizedBox(height: 10),
          Text(
            'No wallet assets available here yet.',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This selector now follows the supported wallet assets only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
