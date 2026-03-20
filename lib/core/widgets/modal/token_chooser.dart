import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/features/wallet_home/presentation/screens/manage_wallet_assets_screen.dart';

Future<void> showTokenSelector(
  BuildContext context,
  String address, {
  double Function(AssetModel asset)? balanceResolver,
  required Widget Function(String address, String token, double balance)
  screenBuilder,
  String title = 'Select Asset',
}) async {
  final assetVM = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(assetVmProvider);

  double balanceFor(AssetModel a) {
    if (balanceResolver != null) {
      return balanceResolver(a);
    }
    return 0.0;
  }

  void open(AssetModel a) {
    final bal = balanceFor(a);
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screenBuilder(address, a.id, bal)),
    );
  }

  await showAppModalBottomSheet(
    context,
    builder: (ctx) => _TokenSelectorSheet(
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
  final void Function(AssetModel) onSelect;

  @override
  ConsumerState<_TokenSelectorSheet> createState() => _TokenSelectorSheetState();
}

class _TokenSelectorSheetState extends ConsumerState<_TokenSelectorSheet> {
  String? _selectedAssetId;

  @override
  void initState() {
    super.initState();
    _selectedAssetId = widget.assets.isEmpty ? null : widget.assets.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final assets = ref.watch(assetVmProvider).walletHomeAssets;
    final selectedAssetId = assets.any((asset) => asset.id == _selectedAssetId)
        ? _selectedAssetId
        : (assets.isEmpty ? null : assets.first.id);
    final selectedAsset = selectedAssetId == null
        ? null
        : assets.firstWhere((asset) => asset.id == selectedAssetId);

    return AppModalBase(
      maxHeightFactor: 0.5,
      backgroundColor: c.background,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: widget.title,
            visibleAssetCount: assets.length,
            totalAssetCount: widget.allAssetCount,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: assets.isEmpty
                ? _EmptyState(
                    onViewMore: () => _openManageAssets(context),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: assets.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == assets.length) {
                        return _ViewMoreTile(
                          onTap: () => _openManageAssets(context),
                        );
                      }

                      final asset = assets[index];
                      final selected = asset.id == selectedAssetId;
                      return _SelectableTokenTile(
                        asset: asset,
                        balance: widget.balanceFor(asset),
                        selected: selected,
                        onTap: () {
                          setState(() => _selectedAssetId = asset.id);
                          widget.onSelect(asset);
                        },
                      );
                    },
                  ),
          ),
          if (selectedAsset != null) ...[
            const SizedBox(height: 12),
            _SelectedHint(
              asset: selectedAsset,
              balance: widget.balanceFor(selectedAsset),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openManageAssets(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageWalletAssetsScreen()),
    );
    if (!mounted) return;
    final updatedAssets = ref.read(assetVmProvider).walletHomeAssets;
    setState(() {
      _selectedAssetId = updatedAssets.any((a) => a.id == _selectedAssetId)
          ? _selectedAssetId
          : (updatedAssets.isEmpty ? null : updatedAssets.first.id);
    });
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
    final c = AppColor.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: c.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            LucideIcons.coins,
            color: c.onPrimary,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$visibleAssetCount shown · $totalAssetCount available',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectableTokenTile extends StatelessWidget {
  const _SelectableTokenTile({
    required this.asset,
    required this.balance,
    required this.selected,
    required this.onTap,
  });

  final AssetModel asset;
  final double balance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? c.primary.withValues(alpha: 0.7)
                  : c.border.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: c.textPrimary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AssetLogo(keyOrSymbol: asset.id, size: 40, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol.toUpperCase(),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Balance: ${_formatBalance(balance)}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? LucideIcons.checkCircle2
                    : LucideIcons.circle,
                color: selected ? c.primary : c.textMuted,
                size: 20,
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

class _ViewMoreTile extends StatelessWidget {
  const _ViewMoreTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.textPrimary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.listPlus,
                color: c.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View more assets',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Choose which assets appear in this selector.',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: c.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedHint extends StatelessWidget {
  const _SelectedHint({
    required this.asset,
    required this.balance,
  });

  final AssetModel asset;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.badgeCheck,
            color: c.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selected: ${asset.symbol.toUpperCase()} · Balance ${_formatBalance(balance)}',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBalance(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1000) return NumberFormat.compact().format(value);
    if (value.abs() >= 1) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onViewMore});

  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.coins,
            color: c.textMuted,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            'No wallet-home assets selected yet.',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Open asset management and choose what should appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onViewMore,
            child: const Text('View More Assets'),
          ),
        ],
      ),
    );
  }
}
