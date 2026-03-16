import 'package:flutter/material.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/core/utils/link_opener.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/asset/asset_logo.dart';
import 'package:next_fi/core/widgets/button/custom_button.dart';
import 'package:next_fi/features/contact/presentation/viewmodels/contact_list_notifier.dart';
import 'package:next_fi/features/transactions/data/models/tx.dart';
import 'package:next_fi/core/widgets/modal/recipient_upsert_sheet.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'key_value_row.dart';

final DateFormat _detailFmt = DateFormat('MMM d, yyyy - h:mm a');

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
  final isTestnet = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(transactionsVmProvider).isTestnet;

  final recipProv = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(contactListProvider);
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
                // drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (isIncoming ? colors.success : colors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (isIncoming ? colors.success : colors.error)
                              .withValues(alpha: 0.3),
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

                // Amount + asset
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssetLogo(keyOrSymbol: asset), // uses AssetVM via Provider
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

                // Contact badge + Save/Edit
                Row(
                  children: [
                    if (existing != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(existing.color).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Color(
                              existing.color,
                            ).withValues(alpha: 0.35),
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

                    // Tertiary action
                    AppTextButton.icon(
                      onPressed: () async {
                        final saved = await showRecipientUpsertSheet(
                          context,
                          initial: existing,
                        );
                        if (!context.mounted) return;
                        if (saved == true) {
                          final updated = ProviderScope.containerOf(
                            context,
                            listen: false,
                          ).read(contactListProvider).byAddress(peerAddr);
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

                // Date/time
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendarClock,
                      size: 16,
                      color: colors.textSecondary,
                    ),
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

                // Key/Value details
                KeyValueRow(label: 'From', value: from, copyable: true),
                const SizedBox(height: 8),
                KeyValueRow(label: 'To', value: to, copyable: true),
                const SizedBox(height: 8),
                KeyValueRow(
                  label: 'Tx Hash',
                  value: hash,
                  mono: true,
                  copyable: true,
                ),
                const SizedBox(height: 16),

                // Actions (CustomButton)
                Row(
                  children: [
                    // Copy Hash (outlined / disabled)
                    Expanded(
                      child: CustomButton(
                        text: 'Copy Hash',
                        icon: LucideIcons.copy,
                        type: (hash.isEmpty)
                            ? ButtonType.disabled
                            : ButtonType.outlined,
                        onPressed: () async {
                          if (hash.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: hash));
                          if (!context.mounted) return;
                          showFloatingSnackBar(
                            context,
                            message: 'Hash copied',
                            type: SnackBarType.success,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Explorer (filled / disabled) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â uses LinkOpener
                    Expanded(
                      child: CustomButton(
                        text: 'Explorer',
                        icon: LucideIcons.externalLink,
                        type: (hash.isEmpty)
                            ? ButtonType.disabled
                            : ButtonType.filled,
                        onPressed: () async {
                          if (hash.isEmpty) return;
                          await LinkOpener.openStellarTx(
                            context,
                            hash: hash,
                            isTestnet: isTestnet,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Done (outlined, full width)
                CustomButton(
                  text: 'Done',
                  icon: LucideIcons.check,
                  type: ButtonType.outlined,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

