import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/oath2.0/token_storage.dart';
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  List<WalletViewModel> _localWallets = [];
  List<CloudWallet> _cloudWallets = [];
  bool _isLoading = true;
  bool _isRemoving = false;
  String? _error;

  // Responsive helper methods
  double _getResponsiveValue(BuildContext context, {
    required double mobile,
    required double tablet,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 768) return tablet;
    return mobile;
  }

  double _getPadding(BuildContext context) =>
      _getResponsiveValue(context, mobile: 16, tablet: 24);

  double _getRadius(BuildContext context) =>
      _getResponsiveValue(context, mobile: 16, tablet: 20);

  double _getFontScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 0.9; // Small phones
    if (width >= 768) return 1.1; // Tablets
    return 1.0; // Normal phones
  }

  double _getMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 768) return 600; // Max width for tablets
    return width; // Full width for phones
  }

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
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
    final pad = _getPadding(context);
    final fontScale = _getFontScale(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * fontScale),
        ),
        title: Row(
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: widget.colors.error,
              size: 24 * fontScale,
            ),
            SizedBox(width: 12 * fontScale),
            Flexible(
              child: Text(
                'Remove Wallet',
                style: TextStyle(
                  color: widget.colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18 * fontScale,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "${wallet.label}" from cloud?\n\nThis wallet has no local seed and cannot be recovered unless you import it again.',
          style: TextStyle(
            color: widget.colors.textSecondary,
            height: 1.5,
            fontSize: 14 * fontScale,
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
                fontSize: 14 * fontScale,
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
                fontSize: 14 * fontScale,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isRemoving = true);

      // Remove from backend
      await WalletCoreService.I.remove(walletId: wallet.backendId);

      // Update local list
      if (mounted) {
        setState(() {
          _cloudWallets.removeWhere((w) => w.backendId == wallet.backendId);
          _isRemoving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${wallet.label} removed from cloud'),
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
    final fontScale = _getFontScale(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20 * fontScale),
        ),
        title: Row(
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: widget.colors.error,
              size: 24 * fontScale,
            ),
            SizedBox(width: 12 * fontScale),
            Flexible(
              child: Text(
                'Delete Wallet',
                style: TextStyle(
                  color: widget.colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18 * fontScale,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Delete "${wallet.name}"?\n\n⚠️ WARNING: This will permanently delete the wallet and its seed phrase from this device. Make sure you have backed up your seed phrase!',
          style: TextStyle(
            color: widget.colors.textSecondary,
            height: 1.5,
            fontSize: 14 * fontScale,
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
                fontSize: 14 * fontScale,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: widget.colors.error,
                fontWeight: FontWeight.w700,
                fontSize: 14 * fontScale,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isRemoving = true);

      // Delete wallet (local + backend)
      await WalletManager.I.deleteWallet(localId: wallet.localId);

      // Update local list
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
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = _getMaxWidth(context);
    final pad = _getPadding(context);
    final radius = _getRadius(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: screenWidth >= 768 ? 80 : 60,
            ),
            child: Center(
              child: Container(
                width: maxWidth,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: screenWidth >= 768 ? 24 : 0,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: widget.colors.surface,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28 * (radius / 16)),
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
                          SizedBox(height: 8 * _getFontScale(context)),
                          Flexible(
                            child: _isLoading
                                ? _buildLoadingState()
                                : _error != null
                                ? _buildErrorState()
                                : totalWallets == 0
                                ? _buildEmptyState()
                                : _buildWalletList(),
                          ),
                          _buildFooterActions(context),
                        ],
                      ),
                    ),
                    if (_isRemoving)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28 * (radius / 16)),
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
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final fontScale = _getFontScale(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: widget.colors.primary,
            strokeWidth: 3 * fontScale,
          ),
          SizedBox(height: 16 * fontScale),
          Text(
            'Loading wallets...',
            style: TextStyle(
              color: widget.colors.textSecondary,
              fontSize: 14 * fontScale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final pad = _getPadding(context);
    final fontScale = _getFontScale(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48 * fontScale,
              color: widget.colors.error,
            ),
            SizedBox(height: 16 * fontScale),
            Text(
              'Failed to load wallets',
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontSize: 16 * fontScale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8 * fontScale),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                color: widget.colors.textSecondary,
                fontSize: 13 * fontScale,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24 * fontScale),
            _ModernButton(
              text: 'Retry',
              icon: LucideIcons.refreshCw,
              colors: widget.colors,
              isPrimary: true,
              fontScale: fontScale,
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadWallets();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalWallets) {
    final pad = _getPadding(context);
    final fontScale = _getFontScale(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        SizedBox(height: 12 * fontScale),
        // Sheet handle
        Container(
          width: 40 * fontScale,
          height: 4 * fontScale,
          decoration: BoxDecoration(
            color: widget.colors.border.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2 * fontScale),
          ),
        ),
        SizedBox(height: 20 * fontScale),
        // Header with title and action
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: screenWidth < 360
              ? Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12 * fontScale),
                    decoration: BoxDecoration(
                      color: widget.colors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14 * fontScale),
                      border: Border.all(
                        color: widget.colors.primary.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.shuffle,
                      color: widget.colors.primary,
                      size: 22 * fontScale,
                    ),
                  ),
                  SizedBox(width: 14 * fontScale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Switch Wallet",
                          style: TextStyle(
                            color: widget.colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20 * fontScale,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 2 * fontScale),
                        Text(
                          "$totalWallets wallet${totalWallets != 1 ? 's' : ''} available",
                          style: TextStyle(
                            color: widget.colors.textSecondary.withOpacity(0.7),
                            fontSize: 13 * fontScale,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.allowGenerate) ...[
                SizedBox(height: 12 * fontScale),
                SizedBox(
                  width: double.infinity,
                  child: _NewWalletButton(
                    label: widget.newWalletLabel,
                    colors: widget.colors,
                    fontScale: fontScale,
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const WalletSwitchResult(createNew: true),
                      );
                    },
                  ),
                ),
              ],
            ],
          )
              : Row(
            children: [
              Container(
                padding: EdgeInsets.all(12 * fontScale),
                decoration: BoxDecoration(
                  color: widget.colors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14 * fontScale),
                  border: Border.all(
                    color: widget.colors.primary.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Icon(
                  LucideIcons.shuffle,
                  color: widget.colors.primary,
                  size: 22 * fontScale,
                ),
              ),
              SizedBox(width: 14 * fontScale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Switch Wallet",
                      style: TextStyle(
                        color: widget.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20 * fontScale,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 2 * fontScale),
                    Text(
                      "$totalWallets wallet${totalWallets != 1 ? 's' : ''} available",
                      style: TextStyle(
                        color: widget.colors.textSecondary.withOpacity(0.7),
                        fontSize: 13 * fontScale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowGenerate)
                _NewWalletButton(
                  label: widget.newWalletLabel,
                  colors: widget.colors,
                  fontScale: fontScale,
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
        SizedBox(height: 16 * fontScale),
        Container(
          height: 1,
          margin: EdgeInsets.symmetric(horizontal: pad),
          color: widget.colors.border.withOpacity(0.15),
        ),
      ],
    );
  }

  Widget _buildWalletList() {
    final pad = _getPadding(context);
    final fontScale = _getFontScale(context);

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(
        horizontal: pad,
        vertical: 12 * fontScale,
      ),
      children: [
        // Local wallets section
        if (_localWallets.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(
              bottom: 12 * fontScale,
              top: 4 * fontScale,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.shield,
                  size: 14 * fontScale,
                  color: widget.colors.success,
                ),
                SizedBox(width: 6 * fontScale),
                Text(
                  'MY WALLETS',
                  style: TextStyle(
                    fontSize: 12 * fontScale,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.textSecondary.withOpacity(0.8),
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 8 * fontScale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * fontScale,
                    vertical: 2 * fontScale,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6 * fontScale),
                  ),
                  child: Text(
                    '${_localWallets.length}',
                    style: TextStyle(
                      fontSize: 11 * fontScale,
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
              padding: EdgeInsets.only(bottom: 8 * fontScale),
              child: _WalletCard(
                wallet: wallet,
                isActive: isActive,
                colors: widget.colors,
                fontScale: fontScale,
                delay: Duration(milliseconds: i * 50),
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

        // Cloud-only wallets section
        if (_cloudWallets.isNotEmpty) ...[
          if (_localWallets.isNotEmpty) SizedBox(height: 12 * fontScale),
          Padding(
            padding: EdgeInsets.only(
              bottom: 12 * fontScale,
              top: 4 * fontScale,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.cloud,
                  size: 14 * fontScale,
                  color: widget.colors.warning,
                ),
                SizedBox(width: 6 * fontScale),
                Text(
                  'CLOUD ONLY',
                  style: TextStyle(
                    fontSize: 12 * fontScale,
                    fontWeight: FontWeight.w700,
                    color: widget.colors.warning,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 8 * fontScale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * fontScale,
                    vertical: 2 * fontScale,
                  ),
                  decoration: BoxDecoration(
                    color: widget.colors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6 * fontScale),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.alertTriangle,
                        size: 10 * fontScale,
                        color: widget.colors.warning,
                      ),
                      SizedBox(width: 4 * fontScale),
                      Text(
                        'No seed',
                        style: TextStyle(
                          fontSize: 11 * fontScale,
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
              padding: EdgeInsets.only(bottom: 8 * fontScale),
              child: _CloudWalletCard(
                wallet: wallet,
                colors: widget.colors,
                fontScale: fontScale,
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
    final pad = _getPadding(context);
    final radius = _getRadius(context);
    final fontScale = _getFontScale(context);

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: 48 * fontScale,
          horizontal: 24 * fontScale,
        ),
        decoration: BoxDecoration(
          color: widget.colors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: widget.colors.border.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20 * fontScale),
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
                size: 40 * fontScale,
                color: widget.colors.primary,
              ),
            ),
            SizedBox(height: 20 * fontScale),
            Text(
              'No wallets yet',
              style: TextStyle(
                color: widget.colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18 * fontScale,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 8 * fontScale),
            Text(
              'Create a new wallet or import an existing one to get started.',
              style: TextStyle(
                color: widget.colors.textSecondary.withOpacity(0.8),
                height: 1.5,
                fontSize: 14 * fontScale,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    final pad = _getPadding(context);
    final fontScale = _getFontScale(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: widget.colors.border.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: screenWidth < 360
          ? Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: _ModernButton(
              text: 'Close',
              icon: LucideIcons.x,
              colors: widget.colors,
              fontScale: fontScale,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.allowGenerate) SizedBox(height: 12 * fontScale),
          if (widget.allowGenerate)
            SizedBox(
              width: double.infinity,
              child: _ModernButton(
                text: widget.importLabel,
                icon: LucideIcons.download,
                colors: widget.colors,
                fontScale: fontScale,
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
      )
          : Row(
        children: [
          Expanded(
            child: _ModernButton(
              text: 'Close',
              icon: LucideIcons.x,
              colors: widget.colors,
              fontScale: fontScale,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.allowGenerate) SizedBox(width: 12 * fontScale),
          if (widget.allowGenerate)
            Expanded(
              child: _ModernButton(
                text: widget.importLabel,
                icon: LucideIcons.download,
                colors: widget.colors,
                fontScale: fontScale,
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

// ── Wallet Card Widget (With Top-Right Delete Button) ──────────────────────

class _WalletCard extends StatefulWidget {
  const _WalletCard({
    required this.wallet,
    required this.isActive,
    required this.colors,
    required this.fontScale,
    required this.delay,
    this.onTap,
    this.onDelete,
  });

  final WalletViewModel wallet;
  final bool isActive;
  final AppColor colors;
  final double fontScale;
  final Duration delay;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

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
    final fontScale = widget.fontScale;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Stack(
          children: [
            // Main card content
            GestureDetector(
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
                padding: EdgeInsets.all(16 * fontScale),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? widget.colors.primary.withOpacity(0.08)
                      : (_isPressed
                      ? widget.colors.background.withOpacity(0.8)
                      : widget.colors.background.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(16 * fontScale),
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
                      width: 48 * fontScale,
                      height: 48 * fontScale,
                      decoration: BoxDecoration(
                        color: widget.isActive
                            ? widget.colors.success.withOpacity(0.1)
                            : widget.colors.background.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12 * fontScale),
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
                        size: 22 * fontScale,
                      ),
                    ),
                    SizedBox(width: 14 * fontScale),
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
                              fontSize: 15 * fontScale,
                              color: widget.colors.textPrimary,
                              letterSpacing: -0.1,
                            ),
                          ),
                          if (widget.wallet.publicAddress?.isNotEmpty ?? false) ...[
                            SizedBox(height: 4 * fontScale),
                            Text(
                              _truncateAddress(widget.wallet.publicAddress!),
                              style: TextStyle(
                                color: widget.colors.textSecondary.withOpacity(0.7),
                                fontSize: 12 * fontScale,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Add spacing for delete button if not active
                    if (!widget.isActive && widget.onDelete != null)
                      SizedBox(width: 40 * fontScale),
                    // Active badge or chevron
                    if (widget.isActive)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * fontScale,
                          vertical: 6 * fontScale,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8 * fontScale),
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
                              size: 12 * fontScale,
                              color: widget.colors.success,
                            ),
                            SizedBox(width: 4 * fontScale),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: widget.colors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 11 * fontScale,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.onDelete == null)
                      Icon(
                        LucideIcons.chevronRight,
                        size: 18 * fontScale,
                        color: widget.colors.textSecondary.withOpacity(0.4),
                      ),
                  ],
                ),
              ),
            ),
            // Delete button - positioned in top-right corner
            if (widget.onDelete != null && !widget.isActive)
              Positioned(
                top: 6 * fontScale,
                right: 6 * fontScale,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onDelete,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: EdgeInsets.all(10 * fontScale),
                      decoration: BoxDecoration(
                        color: widget.colors.error.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.colors.error.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.colors.error.withOpacity(0.1),
                            blurRadius: 6 * fontScale,
                            offset: Offset(0, 2 * fontScale),
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 14 * fontScale,
                        color: widget.colors.error,
                      ),
                    ),
                  ),
                ),
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

// ── Cloud Wallet Card Widget ────────────────────────────────────────────────

class _CloudWalletCard extends StatefulWidget {
  const _CloudWalletCard({
    required this.wallet,
    required this.colors,
    required this.fontScale,
    required this.delay,
    required this.onRemove,
  });

  final CloudWallet wallet;
  final AppColor colors;
  final double fontScale;
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
    final fontScale = widget.fontScale;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          padding: EdgeInsets.all(16 * fontScale),
          decoration: BoxDecoration(
            color: widget.colors.warning.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16 * fontScale),
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
                    width: 48 * fontScale,
                    height: 48 * fontScale,
                    decoration: BoxDecoration(
                      color: widget.colors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12 * fontScale),
                      border: Border.all(
                        color: widget.colors.warning.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.cloud,
                      color: widget.colors.warning,
                      size: 22 * fontScale,
                    ),
                  ),
                  Positioned(
                    right: -2 * fontScale,
                    top: -2 * fontScale,
                    child: Container(
                      padding: EdgeInsets.all(4 * fontScale),
                      decoration: BoxDecoration(
                        color: widget.colors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.colors.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.alertTriangle,
                        size: 10 * fontScale,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 14 * fontScale),
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
                        fontSize: 15 * fontScale,
                        color: widget.colors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    SizedBox(height: 4 * fontScale),
                    Text(
                      _truncateAddress(widget.wallet.publicAddress),
                      style: TextStyle(
                        color: widget.colors.textSecondary.withOpacity(0.7),
                        fontSize: 12 * fontScale,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 6 * fontScale),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * fontScale,
                        vertical: 4 * fontScale,
                      ),
                      decoration: BoxDecoration(
                        color: widget.colors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6 * fontScale),
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
                            size: 11 * fontScale,
                            color: widget.colors.warning,
                          ),
                          SizedBox(width: 4 * fontScale),
                          Text(
                            'No local seed • Import to use',
                            style: TextStyle(
                              fontSize: 10 * fontScale,
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
              SizedBox(width: 12 * fontScale),
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
                              blurRadius: 12 * _pulseOpacity.value * fontScale,
                              spreadRadius: 2 * _pulseOpacity.value * fontScale,
                            ),
                          ],
                        ),
                        child: Material(
                          color: widget.colors.error,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: widget.onRemove,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: EdgeInsets.all(12 * fontScale),
                              child: Icon(
                                LucideIcons.trash2,
                                color: Colors.white,
                                size: 18 * fontScale,
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
    required this.fontScale,
    required this.onPressed,
  });

  final String label;
  final AppColor colors;
  final double fontScale;
  final VoidCallback onPressed;

  @override
  State<_NewWalletButton> createState() => _NewWalletButtonState();
}

class _NewWalletButtonState extends State<_NewWalletButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fontScale = widget.fontScale;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: 14 * fontScale,
          vertical: 10 * fontScale,
        ),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.colors.primary.withOpacity(0.9)
              : widget.colors.primary,
          borderRadius: BorderRadius.circular(12 * fontScale),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.25),
              blurRadius: 8 * fontScale,
              offset: Offset(0, 2 * fontScale),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.plus,
              size: 16 * fontScale,
              color: Colors.white,
            ),
            SizedBox(width: 6 * fontScale),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13 * fontScale,
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
    required this.fontScale,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String text;
  final IconData icon;
  final AppColor colors;
  final double fontScale;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fontScale = widget.fontScale;

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
        padding: EdgeInsets.symmetric(
          vertical: 16 * fontScale,
          horizontal: 20 * fontScale,
        ),
        decoration: BoxDecoration(
          color: widget.isPrimary
              ? (_isPressed
              ? widget.colors.primary.withOpacity(0.9)
              : widget.colors.primary)
              : (_isPressed
              ? widget.colors.background.withOpacity(0.8)
              : widget.colors.background.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(14 * fontScale),
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
                blurRadius: 8 * fontScale,
                offset: Offset(0, 2 * fontScale),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 18 * fontScale,
              color: widget.isPrimary
                  ? Colors.white
                  : widget.colors.textPrimary,
            ),
            SizedBox(width: 10 * fontScale),
            Text(
              widget.text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: widget.isPrimary
                    ? Colors.white
                    : widget.colors.textPrimary,
                fontSize: 14 * fontScale,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}