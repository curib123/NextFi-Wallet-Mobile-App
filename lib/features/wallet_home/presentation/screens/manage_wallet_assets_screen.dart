import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';

class ManageWalletAssetsScreen extends ConsumerStatefulWidget {
  const ManageWalletAssetsScreen({super.key});

  @override
  ConsumerState<ManageWalletAssetsScreen> createState() =>
      _ManageWalletAssetsScreenState();
}

class _ManageWalletAssetsScreenState
    extends ConsumerState<ManageWalletAssetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _removingAssetId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final assetVm = ref.watch(assetVmProvider);
    final walletState = ref.watch(walletHomeVmProvider).state;
    final assets = assetVm.assets.where(_matchesQuery).toList();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Manage Assets',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search assets',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Toggle which assets appear on wallet home.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: assets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final asset = assets[index];
                final visible = assetVm.isVisibleInWalletHome(asset.id);
                final balance = walletState.balanceFor(asset.id);
                final canOfferRemove =
                    asset.canManageTrustline &&
                    asset.trustlineRemovable &&
                    balance <= 0.0000001;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: c.textPrimary.withValues(alpha: 0.05),
                        blurRadius: 14,
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
                              asset.symbol,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              asset.name,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _balanceLabel(balance, walletState, asset.id),
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: visible,
                        onChanged: (value) {
                          ref
                              .read(assetVmProvider)
                              .setWalletHomeVisibility(asset.id, value);
                        },
                        activeColor: c.primary,
                      ),
                      if (canOfferRemove)
                        PopupMenuButton<String>(
                          enabled: _removingAssetId != asset.id,
                          onSelected: (_) => _removeTrustline(asset),
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Text('Remove trustline'),
                            ),
                          ],
                          icon: _removingAssetId == asset.id
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.moreVertical, size: 18),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesQuery(AssetModel asset) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return asset.symbol.toLowerCase().contains(q) ||
        asset.name.toLowerCase().contains(q) ||
        asset.id.toLowerCase().contains(q);
  }

  String _balanceLabel(double balance, WalletHomeState state, String assetId) {
    if (assetId == 'stellar') {
      return 'Balance: ${state.spendableXlm.toStringAsFixed(6)}';
    }
    return 'Balance: ${balance.toStringAsFixed(6)}';
  }

  Future<void> _removeTrustline(AssetModel asset) async {
    if (_removingAssetId != null) return;

    final svc = ref.read(stellarWalletServiceProvider);
    final seed = ref.read(seedKeypairProvider);

    Asset toStellarAsset() {
      if (asset.isNative) return Asset.NATIVE;
      final code = (asset.assetCode ?? asset.symbol).trim();
      final issuer = (asset.issuer ?? '').trim();
      return code.length <= 4
          ? AssetTypeCreditAlphaNum4(code, issuer)
          : AssetTypeCreditAlphaNum12(code, issuer);
    }

    setState(() => _removingAssetId = asset.id);
    try {
      final accountId = ref.read(walletHomeVmProvider).state.address;
      if (accountId == null || accountId.isEmpty) {
        throw StateError('No active wallet is loaded.');
      }

      final stellarAsset = toStellarAsset();
      final check = await svc.getTrustlineRemovalCheck(
        accountId: accountId,
        asset: stellarAsset,
      );

      if (!check.canRemove) {
        if (!mounted) return;
        showAppAlert(
          context,
          type: AppAlertType.warning,
          title: 'Trustline not removable',
          subtitle:
              check.blockingReason ??
              'This asset still has balance, liabilities, or other pending obligations.',
          primaryText: 'OK',
        );
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove trustline?'),
          content: Text(
            'Remove ${asset.symbol.toUpperCase()} from this wallet? '
            'This is only safe when the balance is zero. '
            'If another transaction is still settling, the removal may fail.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final keyPair = await seed.deriveKeyPair();
      final txHash = await svc.removeTrustline(
        keyPair: keyPair,
        asset: stellarAsset,
      );
      await ref.read(walletHomeVmProvider).refresh(force: true);

      if (!mounted) return;
      showAppAlert(
        context,
        type: AppAlertType.success,
        title: 'Trustline removed',
        subtitle: 'Transaction: $txHash',
        primaryText: 'OK',
      );
    } catch (e) {
      if (!mounted) return;
      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Failed to remove trustline',
        subtitle: e.toString(),
        primaryText: 'OK',
      );
    } finally {
      if (mounted) {
        setState(() => _removingAssetId = null);
      }
    }
  }
}
