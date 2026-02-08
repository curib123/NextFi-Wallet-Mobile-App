// lib/features/claimable/view/widgets/claimable_card.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/claimable/model/claimable_item.dart';

/// A card widget displaying a claimable balance with all relevant information.
///
/// Shows:
/// - Asset type and amount
/// - Sponsor/recipient address (shortened)
/// - Lock status and unlock time
/// - Expiration status and countdown
/// - Claim / Reclaim button (enabled/disabled based on status)
///
/// Supports received, sent, expired, and reclaimable balances.
class ClaimableCard extends StatelessWidget {
  final ClaimableItem item;
  final bool claiming;
  final VoidCallback onClaim;
  final bool isSent;

  const ClaimableCard({
    super.key,
    required this.item,
    required this.claiming,
    required this.onClaim,
    this.isSent = false,
  });

  static final _dateFmt = DateFormat('MMM d, yyyy · h:mm a');
  static final _amtFmt = NumberFormat('#,##0.######');

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isLocked = item.unlockTime != null && !item.canClaimNow;
    final isExpired = item.expiryTime != null &&
        DateTime.now().isAfter(item.expiryTime!);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? c.error.withValues(alpha: 0.12)
              : item.canClaimNow
              ? c.primary.withValues(alpha: 0.12)
              : c.border.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.12
                  : 0.03,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: asset + amount + status ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Asset logo
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.canClaimNow
                        ? c.primary.withValues(alpha: 0.06)
                        : c.border.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: AssetLogo(
                    keyOrSymbol: item.displayAsset,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Amount and address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_amtFmt.format(item.amount)} ${item.displayAsset}',
                        style: TextStyle(
                          color: isExpired
                              ? c.textSecondary
                              : c.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          decoration: isExpired && !isSent
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            isSent
                                ? LucideIcons.arrowUpRight
                                : LucideIcons.arrowDownLeft,
                            size: 11,
                            color:
                            c.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isSent
                                  ? 'To ${item.shortSponsor}'
                                  : 'From ${item.shortSponsor}',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status badge
                _statusBadge(c, isLocked, isExpired),
              ],
            ),
          ),

          // ── Unlock time row ───────────────────────────────────────────
          if (item.unlockTime != null && !isExpired) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _timeRow(c, isLocked),
            ),
          ] else if (item.lastModified != null && !isExpired) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 12,
                    color: c.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Created ${_dateFmt.format(item.lastModified!.toLocal())}',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Expiry row ────────────────────────────────────────────────
          if (item.expiryTime != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _expiryRow(c, isExpired),
            ),
          ],

          // ── Divider ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Divider(
              height: 1,
              color: c.border.withValues(alpha: 0.1),
            ),
          ),

          // ── Action button ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _buildActionButton(c, isExpired),
          ),
        ],
      ),
    );
  }

  /// Build the action button based on current state and type
  Widget _buildActionButton(AppColor c, bool isExpired) {
    if (claiming) {
      return Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.primary,
            ),
          ),
        ),
      );
    }

    // ── Sender view: reclaimable after expiry ─────────────────────────
    if (isSent && isExpired) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: onClaim, // reclaim uses same claim mechanism
          style: FilledButton.styleFrom(
            backgroundColor: c.warning,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.undo2,
                  size: 16, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Reclaim Funds',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Sender view: not expired ──────────────────────────────────────
    if (isSent) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: c.border.withValues(alpha: 0.15)),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.canClaimNow
                    ? LucideIcons.clock
                    : LucideIcons.lock,
                size: 14,
                color: c.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                item.canClaimNow
                    ? 'Waiting for claim'
                    : 'Locked',
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Recipient view: expired ───────────────────────────────────────
    if (isExpired) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: c.error.withValues(alpha: 0.15)),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.xCircle,
                  size: 14,
                  color: c.error.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'Expired',
                style: TextStyle(
                  color: c.error.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Recipient view: claimable ─────────────────────────────────────
    if (item.canClaimNow) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: c.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.download,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'Claim Now',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Recipient view: locked ────────────────────────────────────────
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: c.border.withValues(alpha: 0.15)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.lock,
              size: 14,
              color: c.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              'Locked',
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build status badge
  Widget _statusBadge(AppColor c, bool isLocked, bool isExpired) {
    late final Color color;
    late final String label;
    late final IconData icon;

    if (isExpired && isSent) {
      color = c.warning;
      label = 'Reclaimable';
      icon = LucideIcons.undo2;
    } else if (isExpired) {
      color = c.error;
      label = 'Expired';
      icon = LucideIcons.xCircle;
    } else if (isSent && isLocked) {
      color = c.warning;
      label = 'Locked';
      icon = LucideIcons.lock;
    } else if (isSent) {
      color = c.primary;
      label = 'Active';
      icon = LucideIcons.clock;
    } else if (isLocked) {
      color = c.warning;
      label = 'Locked';
      icon = LucideIcons.timerReset;
    } else {
      color = c.success;
      label = 'Ready';
      icon = LucideIcons.checkCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Build time/unlock information row
  Widget _timeRow(AppColor c, bool isLocked) {
    final unlock = item.unlockTime!.toLocal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocked
            ? c.warning.withValues(alpha: 0.04)
            : c.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked
              ? c.warning.withValues(alpha: 0.08)
              : c.success.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLocked ? LucideIcons.clock : LucideIcons.unlock,
            size: 14,
            color: isLocked ? c.warning : c.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked ? 'Unlocks' : 'Unlocked',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _dateFmt.format(unlock),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked && item.unlockTimeRemaining != null)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.unlockTimeRemaining!,
                style: TextStyle(
                  color: c.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build expiry information row
  Widget _expiryRow(AppColor c, bool isExpired) {
    final expiry = item.expiryTime!.toLocal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isExpired
            ? c.error.withValues(alpha: 0.04)
            : c.warning.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpired
              ? c.error.withValues(alpha: 0.08)
              : c.warning.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? LucideIcons.xCircle : LucideIcons.timerOff,
            size: 14,
            color: isExpired ? c.error : c.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Expired' : 'Expires',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _dateFmt.format(expiry),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!isExpired && item.expiryTimeRemaining != null)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.expiryTimeRemaining!,
                style: TextStyle(
                  color: c.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}