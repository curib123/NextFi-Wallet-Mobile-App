import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';
import 'package:next_fi/core/services/secure_storage/token_storage.dart';
import 'package:next_fi/core/services/wallet/wallet_core_service.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';

class WalletSwitchResult {
  final String? chosenWalletId;
  final bool createNew;
  final bool importRequested;

  const WalletSwitchResult({
    this.chosenWalletId,
    this.createNew = false,
    this.importRequested = false,
  });
}

Future<WalletSwitchResult?> showWalletSwitchSheet(
  BuildContext context, {
  String? currentActiveId,
  bool allowGenerate = true,
  String generateLabel = 'New Wallet',
  String importLabel = 'Import Wallet',
}) {
  final colors = AppColor.of(context);
  return showModalBottomSheet<WalletSwitchResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColor.of(context).surface,
    builder: (_) => _WalletSwitchSheet(
      colors: colors,
      activeId: currentActiveId,
      allowGenerate: allowGenerate,
      generateLabel: generateLabel,
      importLabel: importLabel,
    ),
  );
}

class _WalletSwitchSheet extends StatefulWidget {
  const _WalletSwitchSheet({
    required this.colors,
    required this.activeId,
    required this.allowGenerate,
    required this.generateLabel,
    required this.importLabel,
  });

  final AppColor colors;
  final String? activeId;
  final bool allowGenerate;
  final String generateLabel;
  final String importLabel;

  @override
  State<_WalletSwitchSheet> createState() => _WalletSwitchSheetState();
}

class _WalletSwitchSheetState extends State<_WalletSwitchSheet> {
  List<WalletViewModel> _localWallets = const [];
  List<CloudWallet> _cloudWallets = const [];
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _togglingId;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isLoggedIn = await TokenStorage().hasTokens;

      if (isLoggedIn) {
        final overview = await WalletManager.I.getWalletOverview();
        if (!mounted) return;
        setState(() {
          _localWallets = overview.localWallets;
          _cloudWallets = overview.cloudOnlyWallets;
          _loading = false;
        });
        return;
      }

      final localWallets = await SeedStorage.listWallets();
      final activeId = widget.activeId ?? await SeedStorage.getActiveWalletId();
      if (!mounted) return;
      setState(() {
        _localWallets = localWallets
            .map(
              (wallet) => WalletViewModel(
                localId: wallet.id,
                backendId: null,
                name: wallet.name,
                publicAddress: wallet.publicAddress,
                createdAt: wallet.createdAt,
                lastUsedAt: wallet.lastUsedAt,
                isActive: wallet.id == activeId,
                syncedToBackend: false,
              ),
            )
            .toList();
        _cloudWallets = const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleActiveWallet(WalletViewModel wallet) async {
    if (wallet.isActive || _togglingId != null) return;
    setState(() => _togglingId = wallet.localId);
    try {
      final success = await WalletManager.I.switchWallet(localId: wallet.localId);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to switch wallet'),
              backgroundColor: widget.colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await _loadWallets();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to switch wallet'),
            backgroundColor: widget.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  Future<void> _removeCloudWallet(CloudWallet wallet) async {
    final ok = await _confirmDialog(
      title: 'Remove Cloud Wallet',
      message:
          'Remove "${wallet.label}" from your cloud wallet list? You can still re-import it later using its seed phrase.',
      primaryLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _working = true);
    try {
      await WalletCoreService.I.remove(walletId: wallet.backendId);
      if (!mounted) return;
      setState(() {
        _cloudWallets = _cloudWallets
            .where((item) => item.backendId != wallet.backendId)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to remove cloud wallet'),
          backgroundColor: widget.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteLocalWallet(WalletViewModel wallet) async {
    final ok = await _confirmDialog(
      title: 'Delete Wallet',
      message:
          'Delete "${wallet.name}" from this device? Make sure your recovery phrase is backed up before continuing.',
      primaryLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _working = true);
    try {
      await WalletManager.I.deleteWallet(localId: wallet.localId);
      if (!mounted) return;
      await _loadWallets();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete wallet'),
          backgroundColor: widget.colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String primaryLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: widget.colors.surface,
          title: Text(
            title,
            style: TextStyle(
              color: widget.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: widget.colors.textSecondary, height: 1.45),
          ),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: widget.colors.textSecondary),
              ),
            ),
            AppTextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                primaryLabel,
                style: TextStyle(
                  color: destructive
                      ? widget.colors.error
                      : widget.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 54),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            decoration: BoxDecoration(
              color: widget.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _SheetHeader(
                  colors: widget.colors,
                  totalCount: _localWallets.length + _cloudWallets.length,
                ),
                Expanded(child: _buildContent()),
                _SheetFooter(
                  colors: widget.colors,
                  allowGenerate: widget.allowGenerate,
                  generateLabel: widget.generateLabel,
                  importLabel: widget.importLabel,
                ),
              ],
            ),
          ),
          if (_working)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: AppColor.of(context).textPrimary.withValues(alpha: 0.16),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.colors.primary),
            const SizedBox(height: 12),
            Text(
              'Loading wallets...',
              style: TextStyle(color: widget.colors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertCircle,
                color: widget.colors.error,
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                'Could not load wallets',
                style: TextStyle(
                  color: widget.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              AppOutlinedButton.icon(
                onPressed: _loadWallets,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final hasWallets = _localWallets.isNotEmpty || _cloudWallets.isNotEmpty;
    if (!hasWallets) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wallet2,
                  color: widget.colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No wallet yet',
                style: TextStyle(
                  color: widget.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create or import a wallet to continue.',
                style: TextStyle(color: widget.colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: widget.colors.primary,
      onRefresh: _loadWallets,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        children: [
          if (_localWallets.isNotEmpty) ...[
            _SectionTitle(colors: widget.colors, title: 'Your Wallets'),
            const SizedBox(height: 8),
            for (final wallet in _localWallets) ...[
              _WalletCard(
                colors: widget.colors,
                wallet: wallet,
                isCurrent: wallet.isActive,
                isToggling: _togglingId == wallet.localId,
                canDelete: !wallet.isActive,
                onToggleActive: () => _toggleActiveWallet(wallet),
                onTap: () => Navigator.pop(
                  context,
                  WalletSwitchResult(chosenWalletId: wallet.localId),
                ),
                onDelete: wallet.isActive
                    ? null
                    : () => _deleteLocalWallet(wallet),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_cloudWallets.isNotEmpty) ...[
            _SectionTitle(colors: widget.colors, title: 'Cloud Wallets'),
            const SizedBox(height: 8),
            for (final wallet in _cloudWallets) ...[
              _CloudWalletCard(
                colors: widget.colors,
                wallet: wallet,
                onRemove: () => _removeCloudWallet(wallet),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.colors, required this.totalCount});

  final AppColor colors;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallets',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '$totalCount available',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(LucideIcons.x, size: 18, color: colors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.colors, required this.title});

  final AppColor colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.colors,
    required this.wallet,
    required this.isCurrent,
    this.isToggling = false,
    required this.canDelete,
    required this.onToggleActive,
    required this.onTap,
    this.onDelete,
  });

  final AppColor colors;
  final WalletViewModel wallet;
  final bool isCurrent;
  final bool isToggling;
  final bool canDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent
              ? colors.primary.withValues(alpha: 0.04)
              : colors.background.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: isCurrent ? 0.1 : 0.06),
              child: Text(
                wallet.name.isNotEmpty ? wallet.name[0].toUpperCase() : 'W',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              color: colors.success,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortAddress(wallet.publicAddress ?? ''),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (isToggling)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              SizedBox(
                height: 26,
                child: Switch.adaptive(
                  value: isCurrent,
                  activeColor: colors.primary,
                  onChanged: isCurrent ? null : (_) => onToggleActive(),
                ),
              ),
            if (canDelete && onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: Icon(LucideIcons.trash2, size: 14, color: colors.error.withValues(alpha: 0.5)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
          ],
        ),
      ),
    );
  }

  String _shortAddress(String raw) {
    if (raw.trim().isEmpty) return 'No public address';
    final value = raw.trim();
    if (value.length < 15) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }
}

class _CloudWalletCard extends StatelessWidget {
  const _CloudWalletCard({
    required this.colors,
    required this.wallet,
    required this.onRemove,
  });

  final AppColor colors;
  final CloudWallet wallet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.warning.withValues(alpha: 0.1),
                child: Icon(LucideIcons.cloud, size: 15, color: colors.warning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _shortAddress(wallet.publicAddress),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No local seed found. Import this wallet to use it on this device.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: AppOutlinedButton.icon(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide.none,
                backgroundColor: colors.error.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.trash2, size: 15),
              label: const Text(
                'Remove',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortAddress(String raw) {
    if (raw.length <= 16) return raw;
    return '${raw.substring(0, 6)}...${raw.substring(raw.length - 6)}';
  }
}


class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.colors,
    required this.allowGenerate,
    required this.generateLabel,
    required this.importLabel,
  });

  final AppColor colors;
  final bool allowGenerate;
  final String generateLabel;
  final String importLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (allowGenerate)
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      const WalletSwitchResult(createNew: true),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: Text(generateLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: AppColor.of(context).onPrimary,
                      elevation: 0,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            if (allowGenerate) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    const WalletSwitchResult(importRequested: true),
                  ),
                  icon: const Icon(LucideIcons.download, size: 15),
                  label: Text(importLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide.none,
                    backgroundColor: colors.background.withValues(alpha: 0.45),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

