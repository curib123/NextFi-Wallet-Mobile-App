import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/recipient_upsert_sheet.dart';
import 'package:next_fi/Components/token_chooser.dart'; // <-- use your selector here
import 'package:next_fi/Provider/RecipientAddressProvider.dart';
import 'package:next_fi/model/recipient_address.dart';
import 'package:next_fi/Screen/send_screen.dart';

/// Recipient list widget (provider-powered)
class RecipientListWidget extends StatelessWidget {
  final AppColor colors;
  final void Function(RecipientAddress)? onSelect;

  /// Needed so we can launch SendScreen directly after the selector.
  final String? fromAddress;   // your wallet (base58)
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
    return Consumer<RecipientAddressProvider>(
      builder: (context, prov, _) {
        if (prov.loading) return const Center(child: CircularProgressIndicator());
        if (prov.items.isEmpty) return _EmptyRecipients(colors: colors);

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: prov.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final r = prov.items[i];
            return RecipientTile(
              colors: colors,
              recipient: r,
              onTap: () async {
                // If the parent wants the raw object, let them handle it.
                if (onSelect != null) {
                  onSelect!(r);
                  return;
                }

                // Otherwise, open token selector -> SendScreen
                final addr = (fromAddress ?? '').trim();
                if (addr.isEmpty) {
                  showFloatingSnackBar(context, message: 'Wallet not ready', type: SnackBarType.warning);
                  return;
                }

                await showTokenSelector(
                  context,
                  addr,
                  (xlmBalance ?? 0),
                  (usdcBalance ?? 0),
                  screenBuilder: (address, token, balance) {
                    // Auto-populate recipient in SendScreen
                    return SendScreen(
                      address: address,
                      token: token,          // 'TRX' or 'USDT'
                      balance: balance,
                      // These two named args should exist in your SendScreen:
                      // prefillAddress & prefillName (you added earlier)
                      prefillAddress: r.address,
                      prefillName: r.name,
                    );
                  },
                  title: 'Select Token',
                );
              },
              onEdit: () async => showRecipientUpsertSheet(context, initial: r),
              onDelete: () async {
                await context.read<RecipientAddressProvider>().remove(r.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recipient removed')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

/// Recipient tile widget
class RecipientTile extends StatelessWidget {
  final AppColor colors;
  final RecipientAddress recipient;
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

  String _short(String a) =>
      a.length <= 20 ? a : '${a.substring(0, 10)}…${a.substring(a.length - 8)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(recipient.color).withOpacity(0.18),
          child: Icon(LucideIcons.user, color: Color(recipient.color)),
        ),
        title: Text(recipient.name,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(_short(recipient.address),
            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: Icon(LucideIcons.moreVertical, color: colors.textSecondary),
          onSelected: (v) async {
            if (v == 'edit') {
              await onEdit;
            } else if (v == 'delete') {
              await onDelete;
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Recipient removed')));
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users, size: 48, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text('No recipients yet',
                style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Save frequently used XLM/USDC addresses for faster sends.',
              style: TextStyle(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final saved = await showRecipientUpsertSheet(context);
                if (saved == true && context.mounted) {
                  showFloatingSnackBar(context, message: 'Recipient Saved', type: SnackBarType.info);
                }
              },
              icon: const Icon(LucideIcons.userPlus),
              label: const Text('Add recipient'),
            ),
          ],
        ),
      ),
    );
  }
}
