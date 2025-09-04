import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/incoming_payment_hints.dart';

/// Shows up to 2 latest incoming hint cards.
/// Simply pass your incoming list and the wallet address.
/// You can reuse it anywhere you want to show these hints.
class IncomingHintsStrip extends StatelessWidget {
  const IncomingHintsStrip({
    super.key,
    required this.colors,
    required this.tronAddress,
    required this.incomingHints,
    required this.onAcknowledge,
  });

  final AppColor colors;
  final String tronAddress;
  final List<Map<String, dynamic>> incomingHints;
  final void Function(Map<String, dynamic> tx) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    if (incomingHints.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final tx in incomingHints.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: incomingPaymentHint(
              tx,
              tronAddress,
              onAcknowledge: () => onAcknowledge(tx),
            ),
          ),
      ],
    );
  }
}

/// Floating button that changes icon based on selected tab:
/// - Tab 0 (Assets): scan icon
/// - Tab 1 (Recipients): plus icon; tapping opens quick-add sheet with **latest incoming**.
/// Put this widget inside a Stack (positioned bottom-right).
class HomeFab extends StatelessWidget {
  const HomeFab({
    super.key,
    required this.colors,
    required this.incomingHints,
  });

  final AppColor colors;
  final List<Map<String, dynamic>> incomingHints;

  @override
  Widget build(BuildContext context) {
    // Read tab index dynamically
    final tabController = DefaultTabController.of(context);
    final activeIndex = tabController?.index ?? 0;
    final isAssets = activeIndex == 0;
    final icon = isAssets ? LucideIcons.scanLine : LucideIcons.plus;

    return Positioned(
      bottom: 10,
      right: 24,
      child: _RoundFab(
        icon: icon,
        color: colors.primary,
        onTap: () {
          if (isAssets) {
            // You can hook your scanner navigation here if desired
            // Example:
            // Navigator.of(context).pushNamed('/qr-scanner');
            showFloatingSnackBar(context, message: 'Open scanner', type: SnackBarType.info);
          } else {
            // Recipients tab: add from latest incoming
            _openQuickAddUsingLatest(context, colors);
          }
        },
      ),
    );
  }

  void _openQuickAddUsingLatest(BuildContext context, AppColor colors) {
    if (incomingHints.isEmpty) {
      showFloatingSnackBar(context, message: 'No incoming transactions yet', type: SnackBarType.info);
      return;
    }
    final latest = incomingHints.first; // newest
    _openQuickAddRecipientFromTx(context, colors, latest);
  }

  void _openQuickAddRecipientFromTx(
      BuildContext context,
      AppColor colors,
      Map<String, dynamic> tx,
      ) {
    final contract = (tx['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fromRaw = (contract['owner_address'] ?? contract['from'] ?? '').toString();

    final tokenSym = (contract['symbol'] ?? '').toString().isNotEmpty
        ? contract['symbol'].toString().toUpperCase()
        : (contract['asset_name'] ?? 'TRX').toString().toUpperCase();

    final tsMs = (tx['timestamp'] as num?)?.toInt();
    final when = tsMs == null
        ? ''
        : DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(tsMs));

    final displayFrom = fromRaw; // can normalize hex41 -> base58 in your add screen

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.userPlus, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Latest incoming', style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary)),
                  const Spacer(),
                  if (when.isNotEmpty)
                    Text(when, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.user, color: colors.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      displayFrom,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.coins, color: colors.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(tokenSym, style: TextStyle(color: colors.textSecondary)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: displayFrom));
                        Navigator.pop(context);
                        showFloatingSnackBar(context, message: 'Address copied', type: SnackBarType.success);
                      },
                      icon: Icon(LucideIcons.copy, color: colors.primary, size: 18),
                      label: Text('Copy', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {

                      },
                      icon: const Icon(LucideIcons.userPlus, color: Colors.white, size: 18),
                      label: const Text('Add recipient'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small circular FAB used by [HomeFab].
class _RoundFab extends StatelessWidget {
  const _RoundFab({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
