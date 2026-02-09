// lib/features/claimable/view/widgets/claimable_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/services/secure_storage/recipient_address_storage.dart';

/// A card widget displaying a claimable balance with all relevant information.
///
/// Shows:
/// - Asset type and amount
/// - Sponsor/recipient address (with saved name if available)
/// - Lock status and unlock time
/// - Expiration status and countdown
/// - Claim / Reclaim button (enabled/disabled based on status)
///
/// Supports received, sent, expired, and reclaimable balances.
class ClaimableCard extends StatefulWidget {
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

  @override
  State<ClaimableCard> createState() => _ClaimableCardState();
}

class _ClaimableCardState extends State<ClaimableCard> {
  static final _dateFmt = DateFormat('MMM d, yyyy · h:mm a');
  static final _amtFmt = NumberFormat('#,##0.######');

  String? _recipientName;
  bool _loadedName = false;

  @override
  void initState() {
    super.initState();
    _loadRecipientName();
  }

  @override
  void didUpdateWidget(ClaimableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.shortSponsor != widget.item.shortSponsor) {
      _loadRecipientName();
    }
  }

  Future<void> _loadRecipientName() async {
    if (_loadedName) return;
    _loadedName = true;

    try {
      final storage = const RecipientAddressStorage();
      final recipients = await storage.readAll();

      final match = recipients.firstWhere(
            (r) => r.address == widget.item.shortSponsor,
        orElse: () => recipients.first, // dummy fallback
      );

      if (match.address == widget.item.shortSponsor && mounted) {
        setState(() => _recipientName = match.name);
      }
    } catch (_) {
      // No saved name found, use address
    }
  }

  String get _displayName {
    if (_recipientName != null && _recipientName!.isNotEmpty) {
      return _recipientName!;
    }
    return widget.item.shortSponsor;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isLocked = widget.item.unlockTime != null && !widget.item.canClaimNow;
    final isExpired = widget.item.expiryTime != null &&
        DateTime.now().isAfter(widget.item.expiryTime!);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.item.canClaimNow
                ? c.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.surface.withOpacity(0.95),
                  c.surface.withOpacity(0.85),
                ],
              ),
              border: Border.all(
                color: isExpired
                    ? c.error.withOpacity(0.2)
                    : widget.item.canClaimNow
                    ? c.primary.withOpacity(0.2)
                    : c.border.withOpacity(0.15),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: asset + amount + status ───────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Asset logo with gradient background
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.item.canClaimNow
                                ? [
                              c.primary.withOpacity(0.12),
                              c.primary.withOpacity(0.06),
                            ]
                                : [
                              c.border.withOpacity(0.1),
                              c.border.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.item.canClaimNow
                                ? c.primary.withOpacity(0.2)
                                : c.border.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: AssetLogo(
                          keyOrSymbol: widget.item.displayAsset,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Amount and recipient
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_amtFmt.format(widget.item.amount)} ${widget.item.displayAsset}',
                              style: TextStyle(
                                color: isExpired
                                    ? c.textSecondary
                                    : c.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: -0.3,
                                decoration: isExpired && !widget.isSent
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        c.textSecondary.withOpacity(0.12),
                                        c.textSecondary.withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    widget.isSent
                                        ? LucideIcons.arrowUpRight
                                        : LucideIcons.arrowDownLeft,
                                    size: 12,
                                    color: c.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.isSent
                                        ? 'To $_displayName'
                                        : 'From $_displayName',
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status badge
                      _statusBadge(c, isLocked, isExpired),
                    ],
                  ),
                ),

                // ── Time information rows ──────────────────────────────────────
                if (widget.item.unlockTime != null && !isExpired)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _timeRow(c, isLocked),
                  )
                else if (widget.item.lastModified != null && !isExpired)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _createdRow(c),
                  ),

                if (widget.item.unlockTime != null && widget.item.expiryTime != null && !isExpired)
                  const SizedBox(height: 12),

                // ── Expiry row ─────────────────────────────────────────────────
                if (widget.item.expiryTime != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _expiryRow(c, isExpired),
                  ),

                // ── Divider ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          c.border.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Action button ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _buildActionButton(c, isExpired),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the action button based on current state and type
  Widget _buildActionButton(AppColor c, bool isExpired) {
    if (widget.claiming) {
      return Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              c.primary.withOpacity(0.08),
              c.primary.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: c.primary,
            ),
          ),
        ),
      );
    }

    // ── Sender view: reclaimable after expiry ─────────────────────────
    if (widget.isSent && isExpired) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.warning,
                c.warning.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.warning.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClaim,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.undo2,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Reclaim Funds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Sender view: active (no action needed) ────────────────────────
    if (widget.isSent && !isExpired) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.primary.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.checkCircle,
                  size: 18,
                  color: c.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Active',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Recipient view: expired (no action) ───────────────────────────
    if (!widget.isSent && isExpired) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: c.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.error.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.xCircle,
                  size: 18,
                  color: c.error,
                ),
                const SizedBox(width: 10),
                Text(
                  'Expired',
                  style: TextStyle(
                    color: c.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Recipient view: ready to claim ────────────────────────────────
    if (widget.item.canClaimNow) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.primary,
                c.primary.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: c.primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClaim,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.download,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Claim Now',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Recipient view: locked ────────────────────────────────────────
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color: c.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.border.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.lock,
                size: 16,
                color: c.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 10),
              Text(
                'Locked',
                style: TextStyle(
                  color: c.textSecondary.withOpacity(0.5),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build status badge
  Widget _statusBadge(AppColor c, bool isLocked, bool isExpired) {
    late final Color color;
    late final String label;
    late final IconData icon;

    if (isExpired && widget.isSent) {
      color = c.warning;
      label = 'Reclaimable';
      icon = LucideIcons.undo2;
    } else if (isExpired) {
      color = c.error;
      label = 'Expired';
      icon = LucideIcons.xCircle;
    } else if (widget.isSent && isLocked) {
      color = c.warning;
      label = 'Locked';
      icon = LucideIcons.lock;
    } else if (widget.isSent) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build created date row
  Widget _createdRow(AppColor c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.textSecondary.withOpacity(0.06),
            c.textSecondary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.border.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              LucideIcons.calendar,
              size: 16,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFmt.format(widget.item.lastModified!.toLocal()),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build time/unlock information row
  Widget _timeRow(AppColor c, bool isLocked) {
    final unlock = widget.item.unlockTime!.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked
              ? [
            c.warning.withOpacity(0.08),
            c.warning.withOpacity(0.04),
          ]
              : [
            c.success.withOpacity(0.08),
            c.success.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocked
              ? c.warning.withOpacity(0.2)
              : c.success.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isLocked
                  ? c.warning.withOpacity(0.12)
                  : c.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLocked ? LucideIcons.clock : LucideIcons.unlock,
              size: 16,
              color: isLocked ? c.warning : c.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked ? 'Unlocks' : 'Unlocked',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFmt.format(unlock),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked && widget.item.unlockTimeRemaining != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.warning.withOpacity(0.15),
                    c.warning.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.item.unlockTimeRemaining!,
                style: TextStyle(
                  color: c.warning,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build expiry information row
  Widget _expiryRow(AppColor c, bool isExpired) {
    final expiry = widget.item.expiryTime!.toLocal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [
            c.error.withOpacity(0.08),
            c.error.withOpacity(0.04),
          ]
              : [
            c.warning.withOpacity(0.08),
            c.warning.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpired
              ? c.error.withOpacity(0.2)
              : c.warning.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isExpired
                  ? c.error.withOpacity(0.12)
                  : c.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpired ? LucideIcons.xCircle : LucideIcons.timerOff,
              size: 16,
              color: isExpired ? c.error : c.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Expired' : 'Expires',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateFmt.format(expiry),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (!isExpired && widget.item.expiryTimeRemaining != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.warning.withOpacity(0.15),
                    c.warning.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.item.expiryTimeRemaining!,
                style: TextStyle(
                  color: c.warning,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}