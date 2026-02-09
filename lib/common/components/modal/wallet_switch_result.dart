import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
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
  final wallets = await SeedStorage.listWallets();

  return showModalBottomSheet<WalletSwitchResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _WalletSwitchBody(
        colors: colors,
        wallets: wallets,
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
    required this.wallets,
    required this.activeId,
    required this.allowGenerate,
    required this.newWalletLabel,
    required this.importLabel,
  });

  final AppColor colors;
  final List<dynamic> wallets;
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

  static const double _pad = 20;
  static const double _radius = 16;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.colors.surface,
                    widget.colors.surface.withOpacity(0.98),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: widget.colors.border.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, -8),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 8),
                  Flexible(
                    child: widget.wallets.isEmpty
                        ? _buildEmptyState()
                        : _buildWalletList(),
                  ),
                  _buildFooterActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Sheet handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.colors.border.withOpacity(0.5),
                widget.colors.border.withOpacity(0.3),
              ],
            ),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.colors.primary.withOpacity(0.12),
                      widget.colors.primary.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.colors.primary.withOpacity(0.2),
                    width: 1.5,
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
                      "${widget.wallets.length} wallet${widget.wallets.length != 1 ? 's' : ''} available",
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
        // Divider with gradient
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: _pad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.colors.border.withOpacity(0),
                widget.colors.border.withOpacity(0.3),
                widget.colors.border.withOpacity(0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 12),
      itemCount: widget.wallets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        return _WalletCard(
          wallet: widget.wallets[i],
          isActive: widget.wallets[i].id == widget.activeId,
          colors: widget.colors,
          delay: Duration(milliseconds: i * 50),
          onTap: () {
            Navigator.pop(
              context,
              WalletSwitchResult(chosenWalletId: widget.wallets[i].id),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(_pad),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.colors.background.withOpacity(0.8),
              widget.colors.background.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: widget.colors.border.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.colors.primary.withOpacity(0.12),
                    widget.colors.primary.withOpacity(0.06),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.colors.primary.withOpacity(0.2),
                  width: 2,
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.colors.surface.withOpacity(0),
            widget.colors.surface,
          ],
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
    required this.onTap,
  });

  final dynamic wallet;
  final bool isActive;
  final AppColor colors;
  final Duration delay;
  final VoidCallback onTap;

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
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: widget.isActive
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.colors.primary.withOpacity(0.12),
                  widget.colors.primary.withOpacity(0.06),
                ],
              )
                  : null,
              color: !widget.isActive
                  ? (_isPressed
                  ? widget.colors.background.withOpacity(0.8)
                  : widget.colors.background.withOpacity(0.5))
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isActive
                    ? widget.colors.primary.withOpacity(0.3)
                    : widget.colors.border.withOpacity(0.2),
                width: widget.isActive ? 2 : 1.5,
              ),
              boxShadow: _isPressed
                  ? []
                  : [
                if (widget.isActive)
                  BoxShadow(
                    color: widget.colors.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isActive
                          ? [
                        widget.colors.success.withOpacity(0.15),
                        widget.colors.success.withOpacity(0.08),
                      ]
                          : [
                        widget.colors.background,
                        widget.colors.background.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isActive
                          ? widget.colors.success.withOpacity(0.3)
                          : widget.colors.border.withOpacity(0.25),
                      width: 1.5,
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.colors.success.withOpacity(0.15),
                          widget.colors.success.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.colors.success.withOpacity(0.35),
                        width: 1.5,
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
                            fontWeight: FontWeight.w800,
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed
                ? [
              widget.colors.primary.withOpacity(0.9),
              widget.colors.primary.withOpacity(0.8),
            ]
                : [
              widget.colors.primary,
              widget.colors.primary.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.3),
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
          gradient: widget.isPrimary
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed
                ? [
              widget.colors.primary.withOpacity(0.9),
              widget.colors.primary.withOpacity(0.8),
            ]
                : [
              widget.colors.primary,
              widget.colors.primary.withOpacity(0.9),
            ],
          )
              : null,
          color: !widget.isPrimary
              ? (_isPressed
              ? widget.colors.background.withOpacity(0.8)
              : widget.colors.background.withOpacity(0.5))
              : null,
          borderRadius: BorderRadius.circular(14),
          border: !widget.isPrimary
              ? Border.all(
            color: widget.colors.border.withOpacity(0.25),
            width: 1.5,
          )
              : null,
          boxShadow: _isPressed
              ? []
              : [
            if (widget.isPrimary)
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
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