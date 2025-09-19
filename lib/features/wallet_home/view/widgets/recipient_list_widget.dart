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

/// Recipient list widget (provider-powered)
class RecipientListWidget extends StatelessWidget {
  final AppColor colors;
  final void Function(RecipientAddressModel)? onSelect; // ✅ align type

  /// Needed so we can launch SendScreen directly after the selector.
  final String? fromAddress; // your wallet
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

    // Reusable FAB
    final fab = FloatingActionButton(
      heroTag: 'recipient_add_fab',
      tooltip: 'Add recipient',
      shape: const CircleBorder(),
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
      child: const Icon(LucideIcons.userPlus),
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: canPop
          ? AppBar(
        title: const Text('Recipients'),
        scrolledUnderElevation: 0,
      )
          : null,
      floatingActionButton: fab,
      body: Consumer<RecipientAddressVM>(
        builder: (context, prov, _) {
          if (prov.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Main body (list or empty state). Pad bottom for FAB.
          final Widget body = prov.items.isEmpty
              ? _EmptyRecipients(colors: colors)
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: prov.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = prov.items[i];

              return RecipientTile(
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
                        token: token, // 'TRX' or 'USDT'
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
              );
            },
          );

          return body;
        },
      ),
    );
  }
}

/// Modern, compact tile for a recipient entry
class RecipientTile extends StatelessWidget {
  final AppColor colors;
  final RecipientAddressModel recipient;
  final VoidCallback? onTap;
  final VoidCallback? onEdit; // <- keep simple; callers can be async inside
  final VoidCallback? onDelete; // <- keep simple; callers can be async inside

  const RecipientTile({
    super.key,
    required this.colors,
    required this.recipient,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

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
    final bg = c.surfaceContainerHighest.withOpacity(.35);
    final accent = Color(recipient.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant.withOpacity(.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _Avatar(
                  color: accent,
                  initial: recipient.name.isNotEmpty
                      ? recipient.name[0].toUpperCase()
                      : '•',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TitleSubtitle(
                    title: recipient.name,
                    subtitle: _short(recipient.address),
                    colors: colors,
                  ),
                ),
                _OverflowMenu(
                  colors: colors,
                  recipient: recipient,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.user, color: color),
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
      children: [
        Text(
          title.isEmpty ? 'Unnamed' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: colors.textSecondary),
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
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(LucideIcons.moreVertical, color: colors.textSecondary),
      onSelected: (v) async {
        if (v == 'copy') {
          await Clipboard.setData(ClipboardData(text: recipient.address));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address copied')),
            );
          }
        } else if (v == 'edit') {
          onEdit?.call();
        } else if (v == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'copy', child: Text('Copy address')),
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients({required this.colors, this.onAdded});
  final AppColor colors;
  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    // Compact mode if screen is narrow or text scale is large
    final bool compact = size.width < 360;

    final double iconSize   = compact ? 36 : 44;
    final double titleSize  = compact ? 14 : 16;
    final double padAll     = compact ? 12 : 16;
    final double gapSm      = compact ? 6  : 8;
    final double gapMd      = compact ? 10 : 12;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(padAll),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: padAll, vertical: padAll),
            decoration: BoxDecoration(
              color: c.surfaceContainerHighest.withOpacity(.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.outlineVariant.withOpacity(.6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.users, size: iconSize, color: colors.textSecondary),
                SizedBox(height: gapMd),
                // Title — single line with ellipsis
                Text(
                  'No recipients yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: gapSm),
                // Subtitle — two lines max to avoid overflow
                Text(
                  'Save frequently used XLM/USDC addresses for faster sends.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: gapMd),
                // Compact button (reduced tap target & padding)
                SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size(compact ? 0 : 140, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final saved = await showRecipientUpsertSheet(context);
                      if (saved == true && context.mounted) {
                        showFloatingSnackBar(
                          context,
                          message: 'Recipient saved',
                          type: SnackBarType.info,
                        );
                        onAdded?.call();
                      }
                    },
                    icon: const Icon(LucideIcons.userPlus, size: 18),
                    label: const Text('Add recipient'),
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
    builder: (ctx) => AlertDialog(
      title: const Text('Remove recipient?'),
      content: Text(
        name.isEmpty
            ? 'This recipient will be removed.'
            : '“$name” will be removed.',
        style: t.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}
