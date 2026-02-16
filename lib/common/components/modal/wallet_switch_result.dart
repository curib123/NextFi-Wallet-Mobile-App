import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/secure_storage/token_storage.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';
import 'package:next_fi/services/secure_storage/seed_storage.dart';

/// Result returned by the switch-wallet sheet.
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

/// Open a modern bottom sheet to switch the active wallet.
///
/// Returns [WalletSwitchResult] with either:
/// - `chosenWalletId` (user picked existing),
/// - `createNew = true` (tapped "New Wallet"),
/// - `importRequested = true` (tapped "Import Wallet").
Future<WalletSwitchResult?> showWalletSwitchSheet(
    BuildContext context, {
      String? currentActiveId,
      bool allowGenerate = true,
      String generateLabel = 'New Wallet',
      String importLabel = 'Import Wallet',
    }) async {
  final colors = AppColor.of(context);

  return showModalBottomSheet<WalletSwitchResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _WalletSwitchBody(
        colors: colors,
        activeId: currentActiveId,
        allowGenerate: allowGenerate,
        newWalletLabel: generateLabel,
        importLabel: importLabel,
      );
    },
  );
}

class _WalletSwitchBody extends StatefulWidget {
  const _WalletSwitchBody({
    required this.colors,
    required this.activeId,
    required this.allowGenerate,
    required this.newWalletLabel,
    required this.importLabel,
  });

  final AppColor colors;
  final String? activeId;
  final bool allowGenerate;
  final String newWalletLabel;
  final String importLabel;

  @override
  State<_WalletSwitchBody> createState() => _WalletSwitchBodyState();
}

class _WalletSwitchBodyState extends State<_WalletSwitchBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<WalletViewModel> _localWallets = [];
  List<CloudWallet> _cloudWallets = [];
  bool _isLoading = true;
  bool _isRemoving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      // Check if user is logged in
      final tokenStorage = TokenStorage();
      final isLoggedIn = await tokenStorage.hasTokens;

      if (isLoggedIn) {
        // User is logged in - fetch from backend (includes cloud wallets)
        final overview = await WalletManager.I.getWalletOverview();

        if (mounted) {
          setState(() {
            _localWallets = overview.localWallets;
            _cloudWallets = overview.cloudOnlyWallets;
            _isLoading = false;
          });
        }
      } else {
        // User NOT logged in - only show local wallets
        final localWallets = await SeedStorage.listWallets();

        if (mounted) {
          setState(() {
            _localWallets = localWallets.map((wallet) {
              return WalletViewModel(
                localId: wallet.id,
                backendId: null,
                name: wallet.name,
                publicAddress: wallet.publicAddress,
                createdAt: wallet.createdAt,
                lastUsedAt: wallet.lastUsedAt,
                isActive: wallet.id == widget.activeId,
                syncedToBackend: false,
              );
            }).toList();
            _cloudWallets = []; // No cloud wallets when not logged in
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _removeCloudWallet(CloudWallet wallet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Wallet'),
        content: Text(
          'Remove "${wallet.label}" from cloud?\n\nThis wallet has no local seed and cannot be recovered unless you import it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: widget.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove', style: TextStyle(color: widget.colors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isRemoving = true);
      await WalletCoreService.I.remove(walletId: wallet.backendId);

      if (mounted) {
        setState(() {
          _cloudWallets.removeWhere((w) => w.backendId == wallet.backendId);
          _isRemoving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wallet.label} removed'),
            backgroundColor: widget.colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: widget.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteLocalWallet(WalletViewModel wallet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Wallet'),
        content: Text(
          'Delete "${wallet.name}"?\n\n⚠️ WARNING: This will permanently delete the wallet and its seed phrase from this device. Make sure you have backed up your seed phrase!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: widget.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: widget.colors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isRemoving = true);
      await WalletManager.I.deleteWallet(localId: wallet.localId);

      if (mounted) {
        setState(() {
          _localWallets.removeWhere((w) => w.localId == wallet.localId);
          _isRemoving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wallet.name} deleted'),
            backgroundColor: widget.colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: widget.colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWallets = _localWallets.length + _cloudWallets.length;
    final screenHeight = MediaQuery.of(context).size.height;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation.drive(
          Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: widget.colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      _buildHeader(totalWallets),
                      const Divider(height: 1),

                      // Content
                      Expanded(
                        child: _isLoading
                            ? _buildLoadingState()
                            : _error != null
                            ? _buildErrorState()
                            : totalWallets == 0
                            ? _buildEmptyState()
                            : _buildWalletList(scrollController),
                      ),

                      // Footer
                      _buildFooter(),
                    ],
                  ),

                  // Loading overlay
                  if (_isRemoving)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int totalWallets) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: widget.colors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title and action
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: widget.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalWallets wallet${totalWallets != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowGenerate)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context, const WalletSwitchResult(createNew: true));
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('New'),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: widget.colors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading wallets...',
            style: TextStyle(color: widget.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: widget.colors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load wallets',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(fontSize: 13, color: widget.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadWallets();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.wallet,
                size: 40,
                color: widget.colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No wallets yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new wallet or import an existing one to get started',
              style: TextStyle(
                fontSize: 14,
                color: widget.colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletList(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Local wallets
        if (_localWallets.isNotEmpty) ...[
          _SectionHeader(
            icon: LucideIcons.shield,
            title: 'MY WALLETS',
            count: _localWallets.length,
            color: widget.colors.success,
          ),
          const SizedBox(height: 12),
          ..._localWallets.map((wallet) {
            final isActive = wallet.localId == widget.activeId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WalletCard(
                wallet: wallet,
                isActive: isActive,
                colors: widget.colors,
                onTap: isActive
                    ? null
                    : () {
                  Navigator.pop(
                    context,
                    WalletSwitchResult(chosenWalletId: wallet.localId),
                  );
                },
                onDelete: isActive ? null : () => _deleteLocalWallet(wallet),
              ),
            );
          }),
        ],

        // Cloud wallets
        if (_cloudWallets.isNotEmpty) ...[
          if (_localWallets.isNotEmpty) const SizedBox(height: 24),
          _SectionHeader(
            icon: LucideIcons.cloud,
            title: 'CLOUD ONLY',
            count: _cloudWallets.length,
            color: widget.colors.warning,
          ),
          const SizedBox(height: 12),
          ..._cloudWallets.map((wallet) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CloudWalletCard(
                wallet: wallet,
                colors: widget.colors,
                onRemove: () => _removeCloudWallet(wallet),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: widget.colors.border.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: widget.colors.border.withOpacity(0.3)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          if (widget.allowGenerate) ...[
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    const WalletSwitchResult(importRequested: true),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: widget.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(widget.importLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ──────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WALLET CARD
// ──────────────────────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.isActive,
    required this.colors,
    this.onTap,
    this.onDelete,
  });

  final WalletViewModel wallet;
  final bool isActive;
  final AppColor colors;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? colors.primary.withOpacity(0.05)
              : colors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? colors.primary.withOpacity(0.3)
                : colors.border.withOpacity(0.2),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? colors.success.withOpacity(0.1)
                    : colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? colors.success.withOpacity(0.2)
                      : colors.border.withOpacity(0.15),
                ),
              ),
              child: Icon(
                isActive ? LucideIcons.checkCircle2 : LucideIcons.wallet,
                color: isActive ? colors.success : colors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (wallet.publicAddress?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      _truncateAddress(wallet.publicAddress!),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary.withOpacity(0.7),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.success.withOpacity(0.2)),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.success,
                  ),
                ),
              )
            else if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: Icon(LucideIcons.trash2, size: 18),
                color: colors.error,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: colors.textSecondary.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CLOUD WALLET CARD
// ──────────────────────────────────────────────────────────────────────────────

class _CloudWalletCard extends StatelessWidget {
  const _CloudWalletCard({
    required this.wallet,
    required this.colors,
    required this.onRemove,
  });

  final CloudWallet wallet;
  final AppColor colors;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.warning.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.warning.withOpacity(0.25)),
                ),
                child: Icon(LucideIcons.cloud, color: colors.warning, size: 20),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                  child: const Icon(
                    LucideIcons.alertTriangle,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _truncateAddress(wallet.publicAddress),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary.withOpacity(0.7),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.key, size: 10, color: colors.warning),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'No seed • Import to use',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.warning,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: colors.error,
            style: IconButton.styleFrom(
              backgroundColor: colors.error.withOpacity(0.1),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}