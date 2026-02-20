import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/features/send/view/send_screen.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/common/components/modal/token_chooser.dart';

/// Recipient list widget (provider-powered) with modern animations and auth checks
class RecipientListWidget extends StatelessWidget {
  final AppColor colors;
  final void Function(RecipientAddressModel)? onSelect;
  final String? fromAddress;
  final double? xlmBalance;
  final double? usdcBalance;
  final VoidCallback? onLoginPressed;

  const RecipientListWidget({
    super.key,
    required this.colors,
    this.onSelect,
    this.fromAddress,
    this.xlmBalance,
    this.usdcBalance,
    this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final mq = MediaQuery.of(context);
    final compact = mq.size.width < 360;
    final fabBottom = 16.0 + mq.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Recipients',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              scrolledUnderElevation: 0,
              centerTitle: false,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: colors.textPrimary,
                  size: 22,
                ),
              ),
            )
          : null,
      body: Consumer<RecipientAddressVM>(
        builder: (context, prov, _) {
          // Check authentication first
          if (!prov.isAuthenticated && !prov.loading) {
            return _NotAuthenticatedView(
              colors: colors,
              onLoginPressed: onLoginPressed,
            );
          }

          if (prov.loading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: colors.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading recipients...',
                    style: TextStyle(
                      color: colors.textSecondary.withOpacity(0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final fab = _ModernAddButton(
            colors: colors,
            compact: compact,
            onPressed: () async {
              if (!prov.isAuthenticated) {
                showFloatingSnackBar(
                  context,
                  message: 'Please login first',
                  type: SnackBarType.warning,
                );
                return;
              }

              final saved = await showRecipientUpsertSheet(context);
              if (saved == true && context.mounted) {
                await prov.refresh();
                showFloatingSnackBar(
                  context,
                  message: 'Recipient saved',
                  type: SnackBarType.info,
                );
              }
            },
          );

          final Widget body = prov.items.isEmpty
              ? _EmptyRecipients(colors: colors)
              : _RecipientList(
                  colors: colors,
                  items: prov.items,
                  onSelect: onSelect,
                  xlmBalance: xlmBalance,
                  usdcBalance: usdcBalance,
                  compact: compact,
                  bottomInset: fabBottom + (compact ? 72 : 84),
                );

          return Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: body,
              ),
              Positioned(
                right: compact ? 14 : 20,
                bottom: fabBottom,
                child: fab,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// View shown when user is not authenticated
class _NotAuthenticatedView extends StatelessWidget {
  final AppColor colors;
  final VoidCallback? onLoginPressed;

  const _NotAuthenticatedView({required this.colors, this.onLoginPressed});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colors.warning.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.warning.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.lock,
                        size: 56,
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Login Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please login first to view and manage your saved recipient addresses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary.withOpacity(0.7),
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Login button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (onLoginPressed != null) {
                          onLoginPressed!();
                        } else {
                          // Default: navigate to login screen
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: colors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.logIn,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Login to Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
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
}

/// Modern add recipient button with clean design
class _ModernAddButton extends StatefulWidget {
  final AppColor colors;
  final VoidCallback onPressed;
  final bool compact;

  const _ModernAddButton({
    required this.colors,
    required this.onPressed,
    required this.compact,
  });

  @override
  State<_ModernAddButton> createState() => _ModernAddButtonState();
}

class _ModernAddButtonState extends State<_ModernAddButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _isPressed ? 0.95 : 1.0,
        child: Container(
          height: widget.compact ? 50 : 56,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 16 : 24),
          decoration: BoxDecoration(
            color: widget.colors.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: widget.colors.primary.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.userPlus, color: Colors.white, size: 20),
              if (!widget.compact) ...[
                const SizedBox(width: 12),
                const Text(
                  'Add Recipient',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  final AppColor colors;
  final List<RecipientAddressModel> items;
  final void Function(RecipientAddressModel)? onSelect;
  final double? xlmBalance;
  final double? usdcBalance;
  final bool compact;
  final double bottomInset;

  const _RecipientList({
    required this.colors,
    required this.items,
    this.onSelect,
    this.xlmBalance,
    this.usdcBalance,
    required this.compact,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        16,
        compact ? 12 : 20,
        bottomInset,
      ),
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => SizedBox(height: compact ? 10 : 12),
      itemBuilder: (context, i) {
        final r = items[i];

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: RecipientTile(
            colors: colors,
            recipient: r,
            onTap: () async {
              if (onSelect != null) {
                HapticFeedback.selectionClick();
                onSelect!(r);
                return;
              }

              final addr = (r.address).trim();
              if (addr.isEmpty) {
                showFloatingSnackBar(
                  context,
                  message: 'Wallet not ready',
                  type: SnackBarType.warning,
                );
                return;
              }

              await showTokenSelector(
                context,
                addr,
                (xlmBalance ?? 0),
                (usdcBalance ?? 0),
                screenBuilder: (address, token, balance) {
                  return SendScreen(
                    address: address,
                    token: token,
                    balance: balance,
                    prefillAddress: r.address,
                    prefillName: r.name,
                  );
                },
                title: 'Select Token',
              );
            },
            onEdit: () async {
              final saved = await showRecipientUpsertSheet(context, initial: r);
              if (saved == true && context.mounted) {
                await context.read<RecipientAddressVM>().refresh();
                showFloatingSnackBar(
                  context,
                  message: 'Recipient updated',
                  type: SnackBarType.info,
                );
              }
            },
            onDelete: () async {
              final ok = await _confirmDelete(context, r.name);
              if (ok != true) return;

              try {
                await context.read<RecipientAddressVM>().remove(r.id);
                if (context.mounted) {
                  showFloatingSnackBar(
                    context,
                    message: 'Recipient removed',
                    type: SnackBarType.warning,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showFloatingSnackBar(
                    context,
                    message: 'Failed to remove: ${e.toString()}',
                    type: SnackBarType.error,
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

/// Modern, smooth recipient tile with transparent background
class RecipientTile extends StatefulWidget {
  final AppColor colors;
  final RecipientAddressModel recipient;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RecipientTile({
    super.key,
    required this.colors,
    required this.recipient,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<RecipientTile> createState() => _RecipientTileState();
}

class _RecipientTileState extends State<RecipientTile> {
  bool _isPressed = false;

  String _short(String a) {
    final s = a.trim();
    if (s.length <= 20) return s;
    final left = s.substring(0, 10);
    final right = s.substring(s.length - 8);
    return '$left...$right';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Color(widget.recipient.color);
    final compact = MediaQuery.of(context).size.width < 360;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isPressed
                ? accent.withOpacity(isDark ? 0.3 : 0.25)
                : widget.colors.border.withOpacity(isDark ? 0.12 : 0.15),
            width: _isPressed ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            _Avatar(
              color: accent,
              compact: compact,
              initial: widget.recipient.name.isNotEmpty
                  ? widget.recipient.name[0].toUpperCase()
                  : '?',
            ),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: _TitleSubtitle(
                title: widget.recipient.name,
                subtitle: _short(widget.recipient.address),
                colors: widget.colors,
                compact: compact,
              ),
            ),
            SizedBox(width: compact ? 4 : 8),
            _OverflowMenu(
              colors: widget.colors,
              recipient: widget.recipient,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.color,
    required this.initial,
    required this.compact,
  });
  final Color color;
  final String initial;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 42 : 48,
      height: compact ? 42 : 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: compact ? 15 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.compact,
  });
  final String title;
  final String subtitle;
  final AppColor colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.isEmpty ? 'Unnamed' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: compact ? 14 : 15,
            color: colors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textSecondary.withOpacity(0.7),
            fontSize: compact ? 12 : 13,
            fontFamily: 'monospace',
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.colors,
    required this.recipient,
    this.onEdit,
    this.onDelete,
  });

  final AppColor colors;
  final RecipientAddressModel recipient;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showMenu(context);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.textSecondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          LucideIcons.moreVertical,
          color: colors.textSecondary.withOpacity(0.7),
          size: 18,
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? colors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: colors.border.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              _MenuTile(
                icon: LucideIcons.copy,
                label: 'Copy address',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(
                    ClipboardData(text: recipient.address),
                  );
                  if (context.mounted) {
                    showFloatingSnackBar(
                      context,
                      message: 'Address copied',
                      type: SnackBarType.info,
                    );
                  }
                },
              ),
              _MenuTile(
                icon: LucideIcons.edit,
                label: 'Edit',
                colors: colors,
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit?.call();
                },
              ),
              _MenuTile(
                icon: LucideIcons.trash2,
                label: 'Delete',
                colors: colors,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete?.call();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColor colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? colors.error : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 360;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(compact ? 20 : 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.users,
                        size: compact ? 48 : 56,
                        color: colors.primary.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: compact ? 24 : 28),
                    Text(
                      'No recipients yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: compact ? 22 : 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    Text(
                      'Save frequently used addresses for faster sends',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary.withOpacity(0.7),
                        fontSize: compact ? 14 : 15,
                        height: 1.5,
                        letterSpacing: -0.2,
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
}

Future<bool?> _confirmDelete(BuildContext context, String name) {
  final colors = AppColor.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? colors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Remove recipient?',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      content: Text(
        name.isEmpty
            ? 'This recipient will be removed.'
            : '"$name" will be removed.',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        AppElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.error.withOpacity(0.12),
            foregroundColor: colors.error,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Remove',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}
