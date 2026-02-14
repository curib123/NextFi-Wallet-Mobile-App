// lib/Screen/WalletHomeScreenWidgets/incoming_payment_hints.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/wallet_home/model/wallet_home_state.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Minimalist incoming payment hint with clean modern design
Widget incomingPaymentHint(
    Map<String, dynamic> tx,
    String me, {
      VoidCallback? onAcknowledge,
      WalletHomeState? walletState,
    }) {
  return Builder(
    builder: (context) {
      final colors = AppColor.of(context);

      final String txId = (tx['hash'] ?? tx['transactionHash'] ?? _randKey()).toString();
      final String from = (tx['from'] ?? 'Unknown').toString();
      final String to = (tx['to'] ?? 'Unknown').toString();

      final String assetType = (tx['assetType'] ?? '').toString();
      final String symbol = _resolveSymbol(tx['assetCode'], assetType);

      final double amount = _toHumanAmount(tx['amount']);
      final int tsMs = _parseMillis(tx['createdAt'] ?? tx['created_at'] ?? tx['timestamp'] ?? tx['time']);

      // Check if this creates a new trustline (reserve impact)
      final isNewAsset = walletState != null &&
          symbol != 'XLM' &&
          !_hasExistingTrustline(walletState, symbol);

      final reserveImpact = isNewAsset ? 0.5 : 0.0;

      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTxDetailsSheet(context, tx, me,
                onAcknowledge: onAcknowledge,
                reserveImpact: reserveImpact),
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: txId));
              showFloatingSnackBar(context, message: 'Transaction ID copied', type: SnackBarType.success);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.success.withOpacity(.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.success.withOpacity(.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '+ ${_fmtAmount(amount)} $symbol',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isNewAsset) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withOpacity(.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: colors.warning,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'from ${_short(from)} • ${_relative(tsMs)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary.withOpacity(0.7),
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: colors.textSecondary.withOpacity(0.5)
                      ),
                    ],
                  ),

                  // Reserve impact warning
                  if (reserveImpact > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.warning.withOpacity(.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.warning.withOpacity(.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.info,
                            size: 13,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Adds ${reserveImpact.toStringAsFixed(1)} XLM reserve for new trustline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.warning,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Enhanced bottom sheet with clean minimal design
void _showTxDetailsSheet(
    BuildContext context,
    Map<String, dynamic> tx,
    String me, {
      VoidCallback? onAcknowledge,
      double reserveImpact = 0.0,
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 36,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.arrowDownLeft, color: colors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming $symbol',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+ ${_fmtAmount(amount)} $symbol',
                      style: TextStyle(
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Details
          _flatRow(ctx, 'From', _short(from), fullValue: from, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'To', to == me ? 'You' : _short(to), fullValue: to, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'When', when, colors: colors),
          _divider(colors),
          _flatRow(ctx, 'TxID', _short(txId), fullValue: txId, colors: colors),

          // Reserve impact
          if (reserveImpact > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.warning.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.shield, size: 17, color: colors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reserve Impact',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '+${reserveImpact.toStringAsFixed(1)} XLM locked for new trustline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Mark as received button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(LucideIcons.check, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onAcknowledge != null) onAcknowledge();
                showFloatingSnackBar(context, message: 'Marked as received', type: SnackBarType.success);
              },
              label: const Text(
                'Mark as received',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _divider(AppColor colors) => Container(
  height: 1,
  margin: const EdgeInsets.symmetric(vertical: 12),
  color: colors.border.withOpacity(0.1),
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
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (fullValue != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            splashRadius: 18,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullValue));
              showFloatingSnackBar(context, message: '$label copied', type: SnackBarType.success);
            },
            icon: Icon(LucideIcons.copy, color: colors.textSecondary.withOpacity(0.5)),
          ),
      ],
    ),
  );
}

// Helper functions
String _randKey() => DateTime.now().microsecondsSinceEpoch.toString();

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
  if (v is num) return v.toDouble();
  final s = v.toString();
  return double.tryParse(s) ?? 0.0;
}

String _fmtAmount(double v) => NumberFormat("#,##0.#######").format(v);

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

bool _hasExistingTrustline(WalletHomeState state, String assetCode) {
  // Check common assets
  if (assetCode == 'XLM') return true;
  if (assetCode == 'USDC') return state.trustlineCount > 0;

  // For uncommon assets, assume it's new if trustline count is low
  return false;
}