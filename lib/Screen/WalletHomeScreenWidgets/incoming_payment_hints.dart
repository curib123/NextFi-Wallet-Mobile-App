// lib/Screen/WalletHomeScreenWidgets/incoming_payment_hints.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Components/SnackBar.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// SLIM, FLAT reminder; tap to view details in a flat bottom sheet.
/// onAcknowledge: called when user marks it as received.
Widget incomingPaymentHint(
    Map<String, dynamic> tx,
    String me, {
      VoidCallback? onAcknowledge,
    }) {
  return Builder(
    builder: (context) {
      final colors = AppColor.of(context);

      // Expecting keys from Payment stream mapping:
      // { hash, from, to, amount, assetCode, assetType, createdAt? }
      final String txId = (tx['hash'] ?? tx['transactionHash'] ?? _randKey()).toString();
      final String from = (tx['from'] ?? 'Unknown').toString();
      final String to = (tx['to'] ?? 'Unknown').toString();

      final String assetType = (tx['assetType'] ?? '').toString();
      final String symbol = _resolveSymbol(tx['assetCode'], assetType);

      final double amount = _toHumanAmount(tx['amount']);
      final int tsMs = _parseMillis(tx['createdAt'] ?? tx['created_at'] ?? tx['timestamp'] ?? tx['time']);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTxDetailsSheet(context, tx, me, onAcknowledge: onAcknowledge),
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: txId));
            showFloatingSnackBar(context, message: 'Transaction ID copied', type: SnackBarType.success);
          },
          borderRadius: BorderRadius.circular(10),
          splashColor: colors.success.withOpacity(.10),
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.success.withOpacity(.06), // flat, no borders/shadows
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(color: colors.success, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '+ ${_fmtAmount(amount)} $symbol ',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        TextSpan(
                          text: '• from ${_short(from)} • ${_relative(tsMs)}',
                          style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, size: 18, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ==== Flat Bottom Sheet with "Mark as received" ====
void _showTxDetailsSheet(
    BuildContext context,
    Map<String, dynamic> tx,
    String me, {
      VoidCallback? onAcknowledge,
    }) {
  final colors = AppColor.of(context);

  final String txId = (tx['hash'] ?? tx['transactionHash'] ?? _randKey()).toString();
  final String from = (tx['from'] ?? 'Unknown').toString();
  final String to = (tx['to'] ?? 'Unknown').toString();

  final String assetType = (tx['assetType'] ?? '').toString();
  final String symbol = _resolveSymbol(tx['assetCode'], assetType);

  final double amount = _toHumanAmount(tx['amount']);

  final int tsMs = _parseMillis(tx['createdAt'] ?? tx['created_at'] ?? tx['timestamp'] ?? tx['time']);
  final String when = tsMs > 0
      ? DateFormat('MMM d, y • HH:mm').format(DateTime.fromMillisecondsSinceEpoch(tsMs))
      : '—';

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 44,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.arrowDownLeft, color: colors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Incoming $symbol',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Text(
                '+ ${_fmtAmount(amount)} $symbol',
                style: TextStyle(color: colors.success, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _flatRow(ctx, 'From', _short(from), fullValue: from, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'To', to == me ? 'You' : _short(to), fullValue: to, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'When', when, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'TxID', _short(txId), fullValue: txId, colors: colors),
          const SizedBox(height: 14),
          // Mark as received
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.check),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0, // flat
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onAcknowledge != null) onAcknowledge();
                showFloatingSnackBar(context, message: 'Marked as received', type: SnackBarType.success);
              },
              label: const Text('Mark as received'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _divider(AppColor colors) => Container(
  height: 1,
  margin: const EdgeInsets.symmetric(vertical: 2),
  color: colors.textSecondary.withOpacity(.06),
);

Widget _flatRow(
    BuildContext context,
    String label,
    String value, {
      String? fullValue,
      required AppColor colors,
    }) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        if (fullValue != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            splashRadius: 18,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullValue));
              showFloatingSnackBar(context, message: '$label copied', type: SnackBarType.success);
            },
            icon: Icon(LucideIcons.copy, color: colors.textSecondary),
          ),
      ],
    ),
  );
}

// ===== helpers =====
String _randKey() => DateTime.now().microsecondsSinceEpoch.toString();

/// Tries to parse either ISO-8601 strings or numeric seconds/millis.
int _parseMillis(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v > 1e12 ? v : v * 1000;
  if (v is num) return v > 1e12 ? v.toInt() : (v * 1000).toInt();
  final s = v.toString().trim();
  try {
    return DateTime.parse(s).millisecondsSinceEpoch;
  } catch (_) {
    final n = num.tryParse(s);
    if (n == null) return 0;
    return n > 1e12 ? n.toInt() : (n * 1000).toInt();
  }
}

String _relative(int tsMs) {
  if (tsMs <= 0) return '—';
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = now - tsMs;
  final s = (diff / 1000).floor();
  if (s < 60) return '${s}s ago';
  final m = (s / 60).floor();
  if (m < 60) return '${m}m ago';
  final h = (m / 60).floor();
  if (h < 24) return '${h}h ago';
  final d = (h / 24).floor();
  if (d < 7) return '${d}d ago';
  return DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(tsMs));
}

double _toHumanAmount(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble(); // Already human units
  final s = v.toString();
  return double.tryParse(s) ?? 0.0; // Stellar amounts are decimal strings
}

String _fmtAmount(double v) => NumberFormat("#,##0.#######").format(v); // up to 7 dp (Stellar)
String _short(String s) {
  if (s.isEmpty || s == 'Unknown') return s;
  if (s.length <= 12) return s;
  return '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
}

String _resolveSymbol(dynamic assetCode, String assetType) {
  final code = (assetCode ?? '').toString().trim();
  if (code.isNotEmpty) return code.toUpperCase();
  if (assetType == Asset.TYPE_NATIVE || assetType.toLowerCase() == 'native') return 'XLM';
  return 'ASSET';
}
