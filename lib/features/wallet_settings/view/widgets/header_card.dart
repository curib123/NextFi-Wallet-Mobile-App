// lib/features/wallet_settings/view/widgets/header_card_refined.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({
    super.key,
    required this.walletName,
    required this.obscured,
    required this.onImport,
    required this.onSwitch,
    required this.onRename,
  });

  final String walletName;
  final bool obscured;
  final VoidCallback onImport;
  final VoidCallback onSwitch;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.surface.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: AppColor.of(context).textPrimary.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Wallet header with icon and status
          Row(
            children: [
              // Wallet icon with gradient background
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.12),
                      colors.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  LucideIcons.wallet,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Wallet name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      walletName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active Wallet',
                      style: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status pill with animation
              _AnimatedStatusPill(
                icon: obscured ? LucideIcons.lock : LucideIcons.unlock,
                label: obscured ? 'Secured' : 'Visible',
                color: obscured ? colors.warning : colors.success,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider with gradient
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.border.withValues(alpha: 0),
                  colors.border.withValues(alpha: 0.3),
                  colors.border.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick actions with modern design
          Row(
            children: [
              Expanded(
                child: _ModernQuickAction(
                  icon: LucideIcons.download,
                  label: 'Import',
                  onTap: onImport,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModernQuickAction(
                  icon: LucideIcons.shuffle,
                  label: 'Switch',
                  onTap: onSwitch,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModernQuickAction(
                  icon: LucideIcons.pencil,
                  label: 'Rename',
                  onTap: onRename,
                  colors: colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernQuickAction extends StatefulWidget {
  const _ModernQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColor colors;

  @override
  State<_ModernQuickAction> createState() => _ModernQuickActionState();
}

class _ModernQuickActionState extends State<_ModernQuickAction> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.colors.primary.withValues(alpha: 0.08)
              : widget.colors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isPressed
                ? widget.colors.primary.withValues(alpha: 0.3)
                : widget.colors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? []
              : [
            BoxShadow(
              color: AppColor.of(context).textPrimary.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 20,
              color: widget.colors.textPrimary,
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.colors.textPrimary,
                fontSize: 13,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStatusPill extends StatelessWidget {
  const _AnimatedStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}