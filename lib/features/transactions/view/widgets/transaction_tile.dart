import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/transactions/model/tx.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'tx_utils.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.colors,
    required this.tx,
    required this.recipProv,
    required this.listFormat,
    required this.onTap,
  });

  final AppColor colors;
  final Tx tx;
  final RecipientAddressVM recipProv;
  final DateFormat listFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final txId = (tx['id'] ?? '').toString();
    final ts = (tx['timestamp'] as num?)?.toInt();
    final dt = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final asset = (tx['asset'] ?? 'XLM').toString();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final from = (tx['from'] ?? '').toString();
    final to = (tx['to'] ?? '').toString();
    final direction = (tx['direction'] ?? 'other').toString();
    final isIncoming = direction == 'in';

    final peerAddr = (isIncoming ? from : to).trim();

    String? recName = (tx['recName'] as String?);
    int? recColor = (tx['recColor'] as int?);
    RecipientAddressModel? rec;

    // hydrate recipient cache if missing on tx
    if (recName == null || recColor == null) {
      rec = recipProv.byAddress(peerAddr);
      if (rec != null) {
        recName = rec.name;
        recColor = rec.color;
        tx['recName'] = recName;
        tx['recColor'] = recColor;
      }
    }

    final titleText = recName != null
        ? '$recName • ${amount.toStringAsFixed(2)} $asset'
        : '${amount.toStringAsFixed(2)} $asset';

    final subtitleWho = isIncoming ? 'From' : 'To';
    final subtitlePeer =
    recName != null ? '$recName (${shortAddr(peerAddr)})' : shortAddr(peerAddr);

    // Leading: your AssetLogo + tiny direction drawer
    Widget leading = Stack(
      clipBehavior: Clip.none,
      children: [
       AssetLogo(keyOrSymbol: asset),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isIncoming ? colors.success : colors.error,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Icon(
              isIncoming ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              size: 10,
              color: colors.onPrimary,
            ),
          ),
        ),
      ],
    );

    return ListTile(
      key: ValueKey(txId.isEmpty ? 'idx:${tx.hashCode}' : txId),
      leading: leading,
      title: Text(
        titleText,
        style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$subtitleWho: $subtitlePeer • ${dt != null ? listFormat.format(dt) : ''}',
        style: TextStyle(color: colors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(LucideIcons.chevronRight, color: colors.textSecondary),
      onTap: onTap,
    );
  }
}
