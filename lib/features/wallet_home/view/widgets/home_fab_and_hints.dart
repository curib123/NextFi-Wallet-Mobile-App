
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/common/components/recipient_upsert_sheet.dart';
import 'package:next_fi/common/components/token_chooser.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/features/send/view/send_screen.dart';
import 'package:next_fi/features/wallet_home/view/widgets/incoming_payment_hint.dart';

/// Shows up to 2 latest incoming hint cards.
/// Simply pass your incoming list and the wallet address.
/// You can reuse it anywhere you want to show these hints.
class IncomingHintsStrip extends StatelessWidget {
  const IncomingHintsStrip({
    super.key,
    required this.colors,
    required this.stellarAddress,
    required this.incomingHints,
    required this.onAcknowledge,
  });

  final AppColor colors;
  final String stellarAddress;
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
              stellarAddress,
              onAcknowledge: () => onAcknowledge(tx),
            ),
          ),
      ],
    );
  }
}

/// Floating button that changes icon based on selected tab:
/// - Tab 0 (Assets): scan icon
/// - Tab 1 (Recipients): plus icon; tapping opens quick-add sheet with latest incoming.
class HomeFab extends StatelessWidget {
  const HomeFab({
    super.key,
    required this.colors,
    required this.incomingHints,
    this.stellarAddress,   // nullable
    this.xlmBalance,    // nullable
    this.usdcBalance,   // nullable
  });

  final AppColor colors;
  final List<Map<String, dynamic>> incomingHints;

  // Nullable fields (wallet may not be loaded on first build)
  final String? stellarAddress;
  final double? xlmBalance;
  final double? usdcBalance;

  bool get _walletReady =>
      stellarAddress != null && xlmBalance != null && usdcBalance != null;

  @override
  Widget build(BuildContext context) {
    final tabController = DefaultTabController.maybeOf(context);

    // If there's no DefaultTabController, default to Assets (scan).
    if (tabController == null) {
      return _buildPositionedFab(context, isAssets: true);
    }

    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final int activeIndex = tabController.index;
        final bool isAssets = activeIndex == 0;
        return _buildPositionedFab(context, isAssets: isAssets);
      },
    );
  }

  Widget _buildPositionedFab(BuildContext context, {required bool isAssets}) {
    final iconData = isAssets ? LucideIcons.scanLine : LucideIcons.plus;

    return Positioned(
      bottom: 10,
      right: 24,
      child: _RoundFab(
        color: colors.primary,
        onTap: () {
          if (isAssets) {
            // Assets tab → send flow (token selector).
            if (!_walletReady) {
              showFloatingSnackBar(
                context,
                message: 'Wallet is loading…',
                type: SnackBarType.info,
              );
              return;
            }
            showTokenSelector(
              context,
              stellarAddress!,      // safe after _walletReady
              xlmBalance!,       // safe after _walletReady
              usdcBalance!,      // safe after _walletReady
              title: 'Send Token',
              screenBuilder: (address, token, balance) => SendScreen(
                address: address,
                token: token,
                balance: balance,
                autoOpenScanner: true,
              ),
            );
          } else {
            // Recipients tab → quick-add using latest incoming hints
            showFloatingSnackBar(
              context,
              message: 'Quick add recipient',
              type: SnackBarType.info,
            );
            // If your sheet supports prefill from hints, pass them here.
            showRecipientUpsertSheet(
              context,
              // incomingHints: incomingHints,
            );
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Icon(
            iconData,
            key: ValueKey(iconData.codePoint),
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Small circular FAB used by [HomeFab].
class _RoundFab extends StatelessWidget {
  const _RoundFab({
    required this.child,
    required this.onTap,
    required this.color,
  });

  final Widget child;
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
          child: Center(child: child),
        ),
      ),
    );
  }
}
