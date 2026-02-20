import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';

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
    backgroundColor: Colors.transparent,
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
    final topRadius = BorderRadius.circular(26);

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
              borderRadius: BorderRadius.vertical(top: topRadius.topLeft),
              border: Border.all(color: widget.colors.border.withOpacity(0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
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
                  color: Colors.black.withOpacity(0.16),
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
                  color: widget.colors.primary.withOpacity(0.1),
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
                isCurrent: wallet.localId == widget.activeId || wallet.isActive,
                canDelete: wallet.localId != widget.activeId,
                onTap: () => Navigator.pop(
                  context,
                  WalletSwitchResult(chosenWalletId: wallet.localId),
                ),
                onDelete: wallet.localId == widget.activeId
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border.withOpacity(0.65),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withOpacity(0.2),
                      colors.primary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wallet,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch Wallet',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalCount wallet${totalCount == 1 ? '' : 's'} available',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AppTextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: colors.textSecondary,
                ),
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
    required this.canDelete,
    required this.onTap,
    this.onDelete,
  });

  final AppColor colors;
  final WalletViewModel wallet;
  final bool isCurrent;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bgColors = isCurrent
        ? [colors.primary.withOpacity(0.16), colors.primary.withOpacity(0.07)]
        : [
            colors.background.withOpacity(0.5),
            colors.surface.withOpacity(0.88),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? colors.primary.withOpacity(0.4)
                  : colors.border.withOpacity(0.22),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(isCurrent ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wallet2,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _shortAddress(wallet.publicAddress ?? ''),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Tag(
                          colors: colors,
                          label: isCurrent ? 'Current' : 'Tap to switch',
                          color: isCurrent ? colors.success : colors.info,
                        ),
                        if (wallet.syncedToBackend)
                          _Tag(
                            colors: colors,
                            label: 'Synced',
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canDelete && onDelete != null)
                AppTextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: colors.error,
                  ),
                )
              else
                Icon(
                  isCurrent
                      ? LucideIcons.checkCircle2
                      : LucideIcons.chevronRight,
                  size: 18,
                  color: isCurrent ? colors.success : colors.textSecondary,
                ),
            ],
          ),
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
        color: colors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.warning.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.cloud, size: 18, color: colors.warning),
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
                side: BorderSide(color: colors.error.withOpacity(0.32)),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.colors, required this.label, required this.color});

  final AppColor colors;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.8,
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border.withOpacity(0.16))),
      ),
      child: Row(
        children: [
          if (allowGenerate)
            Expanded(
              child: AppFilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  const WalletSwitchResult(createNew: true),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(
                  generateLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (allowGenerate) const SizedBox(width: 10),
          Expanded(
            child: AppOutlinedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                const WalletSwitchResult(importRequested: true),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.border.withOpacity(0.34)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.download, size: 16),
              label: Text(
                importLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
