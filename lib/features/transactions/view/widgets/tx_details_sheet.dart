import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/transactions/model/tx.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/common/components/modal/recipient_upsert_sheet.dart';

import 'asset_logo.dart';
import 'key_value_row.dart';
import 'tx_utils.dart';

final DateFormat _detailFmt = DateFormat('MMM d, yyyy • h:mm a');

Future<void> showTxDetailsBottomSheet({
  required BuildContext context,
  required Tx tx,
  required String peerAddr,
  required bool isIncoming,
}) async {
  final colors = AppColor.of(context);

  final ts = (tx['timestamp'] as num?)?.toInt();
  final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

  final asset = (tx['asset'] ?? 'XLM').toString();
  final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
  final from = (tx['from'] ?? '').toString();
  final to = (tx['to'] ?? '').toString();
  final hash = (tx['hash'] ?? '').toString();

  final isTestnet = context.read<TransactionsVM>().isTestnet;
  final explorerUrl = explorerUrlFor(hash, isTestnet);

  final recipProv = context.read<RecipientAddressVM>();
  final existing = recipProv.byAddress(peerAddr);
  if (existing != null) {
    tx['recName'] = existing.name;
    tx['recColor'] = existing.color;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.95,
        initialChildSize: 0.62,
        minChildSize: 0.40,
        builder: (context, scroll) {
          return SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      isIncoming
                          ? LucideIcons.arrowDownCircle
                          : LucideIcons.arrowUpCircle,
                      color: isIncoming ? colors.success : colors.error,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transaction Details',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isIncoming ? colors.success : colors.error)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (isIncoming ? colors.success : colors.error)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        isIncoming ? 'IN' : 'OUT',
                        style: TextStyle(
                          color: isIncoming ? colors.success : colors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetLogo(asset: asset, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${amount.toStringAsFixed(6)} $asset',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (existing != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(existing.color).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Color(existing.color).withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          existing.name,
                          style: TextStyle(
                            color: Color(existing.color),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final saved = await showRecipientUpsertSheet(
                          context,
                          initial: existing,
                        );
                        if (saved == true) {
                          final updated = context
                              .read<RecipientAddressVM>()
                              .byAddress(peerAddr);
                          tx['recName'] = updated?.name;
                          tx['recColor'] = updated?.color;
                        }
                      },
                      icon: Icon(
                        existing != null
                            ? LucideIcons.userCog
                            : LucideIcons.userPlus,
                        size: 16,
                        color: colors.primary,
                      ),
                      label: Text(
                        existing != null ? 'Edit Contact' : 'Save Contact',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.calendarClock,
                        size: 16, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      dt != null ? _detailFmt.format(dt) : 'Unknown date',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                KeyValueRow(
                  label: 'From',
                  value: from,
                  copyable: true,
                ),
                const SizedBox(height: 8),
                KeyValueRow(
                  label: 'To',
                  value: to,
                  copyable: true,
                ),
                const SizedBox(height: 8),
                KeyValueRow(
                  label: 'Tx Hash',
                  value: hash,
                  mono: true,
                  copyable: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hash.isEmpty
                            ? null
                            : () async {
                          await Clipboard.setData(ClipboardData(text: hash));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hash copied')),
                          );
                        },
                        icon: Icon(LucideIcons.copy,
                            size: 18, color: colors.primary),
                        label: Text(
                          'Copy Hash',
                          style: TextStyle(
                              color: colors.primary, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.primary.withOpacity(0.35)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                        (explorerUrl == null || explorerUrl.isEmpty)
                            ? null
                            : () async {
                          await Clipboard.setData(
                              ClipboardData(text: explorerUrl));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Explorer link copied')),
                          );
                        },
                        icon: const Icon(LucideIcons.externalLink,
                            size: 18, color: Colors.white),
                        label: const Text('Explorer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Done'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
