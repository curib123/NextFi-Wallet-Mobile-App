import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';
import 'package:next_fi/services/wallet/wallet_core_service.dart';

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

  // Get wallet overview (local + cloud)
  final overview = await WalletManager.I.getWalletOverview();

  return showModalBottomSheet<WalletSwitchResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _WalletSwitchBody(
        colors: colors,
        localWallets: overview.localWallets,
        cloudWallets: overview.cloudOnlyWallets,
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
    required this.localWallets,
    required this.cloudWallets,
    required this.activeId,
    required this.allowGenerate,
    required this.newWalletLabel,
    required this.importLabel,
  });

  final AppColor colors;
  final List<WalletViewModel> localWallets;
  final List<CloudWallet> cloudWallets;
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  List<WalletViewModel> _localWallets = [];
  List<CloudWallet> _cloudWallets = [];
  bool _isLoading = false;

  static const double _pad = 20;
  static const double _radius = 16;

  @override
  void initState() {
    super.initState();
    _localWallets = widget.localWallets;
    _cloudWallets = widget.cloudWallets;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _removeCloudWallet(CloudWallet wallet) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: widget.colors.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Remove Wallet',
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "${wallet.label}" from cloud?\n\nThis wallet has no local seed and cannot be recovered unless you import it again.',
          style: TextStyle(
            color: widget.colors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: widget.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(
                color: widget.colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      // Remove from backend
      await WalletCoreService.I.remove(walletId: wallet.backendId);

      // Update local list
      setState(() {
        _cloudWallets.removeWhere((w) => w.backendId == wallet.backendId);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wallet.label} removed from cloud'),
            backgroundColor: widget.colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final totalWallets = _localWallets.length + _cloudWallets.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Stack(
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: widget.colors.border.withOpacity(0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(context, totalWallets),
                      const SizedBox(height: 8),
                      Flexible(
                        child: totalWallets == 0
                            ? _buildEmptyState()
                            : _buildWalletList(),
                      ),
                      _buildFooterActions(context),
                    ],
                  ),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalWallets) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Sheet handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: widget.colors.border.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        // Header with title and action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _pad),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.colors.primary.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  LucideIcons.shuffle,
                  color: widget.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Switch Wallet",
                      style: TextStyle(
                        color: widget.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$totalWallets wallet${totalWallets != 1 ? 's' : ''} available",
                      style: TextStyle(
                        color: widget.colors.textSecondary.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // New wallet button
              if (widget.allowGenerate)
                _NewWalletButton(
                  label: widget.newWalletLabel,
                  colors: widget.colors,
                  onPressed: () {
                    Navigator.pop(
                      context,
                      const WalletSwitchResult(createNew: true),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Divider
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: _pad),
          color: widget.colors.border.withOpacity(0.15),
        ),
      ],
    );
  }

  Widget _buildWalletList() {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 12),
      children: [
        // Local wallets section
        if (_localWallets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.shield,
                  size: 14,
                  color: widget.colors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'MY WALLETS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.textSecondary.withOpacity(0.8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_localWallets.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.colors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._localWallets.asMap().entries.map((entry) {
            final i = entry.key;
            final wallet = entry.value;
            final isActive = wallet.localId == widget.activeId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _WalletCard(
                wallet: wallet,
                isActive: isActive,
                colors: widget.colors,
                delay: Duration(milliseconds: i * 50),
                onTap: isActive
                    ? null
                    : () {
                  Navigator.pop(
                    context,
                    WalletSwitchResult(chosenWalletId: wallet.localId),
                  );
                },
              ),
            );
          }),
        ],

        // Cloud-only wallets section
        if (_cloudWallets.isNotEmpty) ...[
          if (_localWallets.isNotEmpty) const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.cloud,
                  size: 14,
                  color: widget.colors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  'CLOUD ONLY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.warning,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.alertTriangle,
                        size: 10,
                        color: widget.colors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'No seed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.colors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ..._cloudWallets.asMap().entries.map((entry) {
            final i = entry.key;
            final wallet = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CloudWalletCard(
                wallet: wallet,
                colors: widget.colors,
                delay: Duration(milliseconds: (_localWallets.length + i) * 50),
                onRemove: () => _removeCloudWallet(wallet),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(_pad),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: widget.colors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: widget.colors.border.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.colors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.colors.primary.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                LucideIcons.wallet,
                size: 40,
                color: widget.colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No wallets yet',
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new wallet or import an existing one to get started.',
              style: TextStyle(
                color: widget.colors.textSecondary.withOpacity(0.8),
                height: 1.5,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.colors.border.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModernButton(
              text: 'Close',
              icon: LucideIcons.x,
              colors: widget.colors,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.allowGenerate) const SizedBox(width: 12),
          if (widget.allowGenerate)
            Expanded(
              child: _ModernButton(
                text: widget.importLabel,
                icon: LucideIcons.download,
                colors: widget.colors,
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(
                    context,
                    const WalletSwitchResult(importRequested: true),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Wallet Card Widget ──────────────────────────────────────────────────────

class _WalletCard extends StatefulWidget {
  const _WalletCard({
    required this.wallet,
    required this.isActive,
    required this.colors,
    required this.delay,
    this.onTap,
  });

  final WalletViewModel wallet;
  final bool isActive;
  final AppColor colors;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.onTap != null
              ? (_) {
            setState(() => _isPressed = false);
            widget.onTap?.call();
          }
              : null,
          onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? widget.colors.primary.withOpacity(0.08)
                  : (_isPressed
                  ? widget.colors.background.withOpacity(0.8)
                  : widget.colors.background.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isActive
                    ? widget.colors.primary.withOpacity(0.25)
                    : widget.colors.border.withOpacity(0.15),
                width: widget.isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? widget.colors.success.withOpacity(0.1)
                        : widget.colors.background.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isActive
                          ? widget.colors.success.withOpacity(0.2)
                          : widget.colors.border.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.isActive
                        ? LucideIcons.checkCircle2
                        : LucideIcons.wallet,
                    color: widget.isActive
                        ? widget.colors.success
                        : widget.colors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Wallet info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.wallet.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: widget.colors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (widget.wallet.publicAddress?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          _truncateAddress(widget.wallet.publicAddress!),
                          style: TextStyle(
                            color: widget.colors.textSecondary.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Active badge
                if (widget.isActive)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.colors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.colors.success.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.check,
                          size: 12,
                          color: widget.colors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: widget.colors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: widget.colors.textSecondary.withOpacity(0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}

// ── Cloud Wallet Card Widget ────────────────────────────────────────────────

class _CloudWalletCard extends StatefulWidget {
  const _CloudWalletCard({
    required this.wallet,
    required this.colors,
    required this.delay,
    required this.onRemove,
  });

  final CloudWallet wallet;
  final AppColor colors;
  final Duration delay;
  final VoidCallback onRemove;

  @override
  State<_CloudWalletCard> createState() => _CloudWalletCardState();
}

class _CloudWalletCardState extends State<_CloudWalletCard>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    // Pulse animation for remove button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.colors.warning.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.colors.warning.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon with warning badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.colors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.colors.warning.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.cloud,
                      color: widget.colors.warning,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.colors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.colors.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.alertTriangle,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Wallet info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.wallet.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: widget.colors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _truncateAddress(widget.wallet.publicAddress),
                      style: TextStyle(
                        color: widget.colors.textSecondary.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.colors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.colors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.key,
                            size: 11,
                            color: widget.colors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'No local seed • Import to use',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: widget.colors.warning,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Animated remove button
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseScale.value,
                    child: Opacity(
                      opacity: _pulseOpacity.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.colors.error.withOpacity(0.4),
                              blurRadius: 12 * _pulseOpacity.value,
                              spreadRadius: 2 * _pulseOpacity.value,
                            ),
                          ],
                        ),
                        child: Material(
                          color: widget.colors.error,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: widget.onRemove,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                LucideIcons.trash2,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }
}

// ── New Wallet Button ───────────────────────────────────────────────────────

class _NewWalletButton extends StatefulWidget {
  const _NewWalletButton({
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final AppColor colors;
  final VoidCallback onPressed;

  @override
  State<_NewWalletButton> createState() => _NewWalletButtonState();
}

class _NewWalletButtonState extends State<_NewWalletButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.colors.primary.withOpacity(0.9)
              : widget.colors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.plus,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modern Button ───────────────────────────────────────────────────────────

class _ModernButton extends StatefulWidget {
  const _ModernButton({
    required this.text,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String text;
  final IconData icon;
  final AppColor colors;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: widget.isPrimary
              ? (_isPressed
              ? widget.colors.primary.withOpacity(0.9)
              : widget.colors.primary)
              : (_isPressed
              ? widget.colors.background.withOpacity(0.8)
              : widget.colors.background.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(14),
          border: !widget.isPrimary
              ? Border.all(
            color: widget.colors.border.withOpacity(0.2),
            width: 1,
          )
              : null,
          boxShadow: _isPressed
              ? []
              : [
            if (widget.isPrimary)
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: widget.isPrimary
                  ? Colors.white
                  : widget.colors.textPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              widget.text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.isPrimary
                    ? Colors.white
                    : widget.colors.textPrimary,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}