import 'package:flutter/material.dart';
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

/// Recipient list widget (provider-powered) with modern animations
class RecipientListWidget extends StatelessWidget {
  final AppColor colors;
  final void Function(RecipientAddressModel)? onSelect;
  final String? fromAddress;
  final double? xlmBalance;
  final double? usdcBalance;

  const RecipientListWidget({
    super.key,
    required this.colors,
    this.onSelect,
    this.fromAddress,
    this.xlmBalance,
    this.usdcBalance,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    final fab = FloatingActionButton.extended(
      heroTag: 'recipient_add_fab',
      tooltip: 'Add recipient',
      elevation: 2,
      highlightElevation: 4,
      icon: const Icon(LucideIcons.userPlus, size: 20),
      label: const Text('Add Recipient'),
      onPressed: () async {
        final saved = await showRecipientUpsertSheet(context);
        if (saved == true && context.mounted) {
          showFloatingSnackBar(
            context,
            message: 'Recipient saved',
            type: SnackBarType.info,
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: canPop
          ? AppBar(
        title: const Text('Recipients'),
        scrolledUnderElevation: 0,
        centerTitle: false,
      )
          : null,
      floatingActionButton: fab,
      body: Consumer<RecipientAddressVM>(
        builder: (context, prov, _) {
          if (prov.loading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading recipients...',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final Widget body = prov.items.isEmpty
              ? _EmptyRecipients(colors: colors)
              : _RecipientList(
            colors: colors,
            items: prov.items,
            onSelect: onSelect,
            xlmBalance: xlmBalance,
            usdcBalance: usdcBalance,
          );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: body,
          );
        },
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

  const _RecipientList({
    required this.colors,
    required this.items,
    this.onSelect,
    this.xlmBalance,
    this.usdcBalance,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = items[i];

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (i * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: RecipientTile(
            colors: colors,
            recipient: r,
            onTap: () async {
              if (onSelect != null) {
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
              final saved = await showRecipientUpsertSheet(
                context,
                initial: r,
              );
              if (saved == true && context.mounted) {
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
              await context.read<RecipientAddressVM>().remove(r.id);
              if (context.mounted) {
                showFloatingSnackBar(
                  context,
                  message: 'Recipient removed',
                  type: SnackBarType.warning,
                );
              }
            },
          ),
        );
      },
    );
  }
}

/// Modern, smooth recipient tile with animations
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
    return '$left…$right';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final accent = Color(widget.recipient.color);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isPressed
                ? accent.withOpacity(.3)
                : widget.colors.border.withOpacity(.2),
            width: _isPressed ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? [
            BoxShadow(
              color: accent.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            _Avatar(
              color: accent,
              initial: widget.recipient.name.isNotEmpty
                  ? widget.recipient.name[0].toUpperCase()
                  : '•',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _TitleSubtitle(
                title: widget.recipient.name,
                subtitle: _short(widget.recipient.address),
                colors: widget.colors,
              ),
            ),
            const SizedBox(width: 8),
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
  const _Avatar({required this.color, required this.initial});
  final Color color;
  final String initial;

  @override
  Widget build(BuildContext context) {
    const size = 50.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(.2),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.user,
        color: color,
        size: 24,
      ),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({
    required this.title,
    required this.subtitle,
    required this.colors,
  });
  final String title;
  final String subtitle;
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.isEmpty ? 'Unnamed' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontSize: 13,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMenu(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            LucideIcons.moreVertical,
            color: colors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _MenuTile(
                icon: LucideIcons.copy,
                label: 'Copy address',
                colors: colors,
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(
                      ClipboardData(text: recipient.address));
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
    final color = isDestructive ? Colors.red : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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

    return Center(
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
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.users,
                    size: compact ? 48 : 64,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: compact ? 20 : 24),
                Text(
                  'No recipients yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  'Save frequently used XLM/USDC addresses for faster sends.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: compact ? 14 : 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, String name) {
  final t = Theme.of(context).textTheme;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Remove recipient?'),
      content: Text(
        name.isEmpty
            ? 'This recipient will be removed.'
            : '"$name" will be removed.',
        style: t.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.15),
            foregroundColor: Colors.red,
          ),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}