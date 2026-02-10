// lib/features/claimable/view/widgets/sent_claimable_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';

/// A slim card widget for SENT claimable balances.
/// Shows recipient info and reclaim functionality for expired balances.
class SentClaimableCard extends StatefulWidget {
  final ClaimableItem item;
  final bool claiming;
  final VoidCallback onClaim;

  const SentClaimableCard({
    super.key,
    required this.item,
    required this.claiming,
    required this.onClaim,
  });

  @override
  State<SentClaimableCard> createState() => _SentClaimableCardState();
}

class _SentClaimableCardState extends State<SentClaimableCard> {
  static final _dateFmt = DateFormat('MMM d, yyyy · h:mm a');
  static final _amtFmt = NumberFormat('#,##0.######');

  RecipientAddressModel? _recipient;
  bool _looked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_looked) {
      _looked = true;
      _resolveRecipient();
    }
  }

  @override
  void didUpdateWidget(SentClaimableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.sponsorId != widget.item.sponsorId) {
      _looked = false;
      _resolveRecipient();
    }
  }

  Future<void> _resolveRecipient() async {
    _looked = true;
    try {
      final vm = context.read<RecipientAddressVM>();
      await vm.ready;
      final match = vm.byAddress(widget.item.sponsorId);
      if (mounted && match != _recipient) {
        setState(() => _recipient = match);
      }
    } catch (_) {}
  }

  bool get _hasSavedName => _recipient != null && _recipient!.name.isNotEmpty;
  Color get _recipientColor => _recipient != null ? Color(_recipient!.color) : Colors.grey;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isLocked = widget.item.unlockTime != null && !widget.item.canClaimNow;
    final isExpired = widget.item.expiryTime != null &&
        DateTime.now().isAfter(widget.item.expiryTime!);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isExpired
                ? c.warning.withOpacity(0.06)
                : c.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                    ? c.warning.withOpacity(0.15)
                    : c.primary.withOpacity(0.1),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Asset logo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isExpired
                            ? [c.warning.withOpacity(0.1), c.warning.withOpacity(0.05)]
                            : [c.primary.withOpacity(0.08), c.primary.withOpacity(0.04)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isExpired
                            ? c.warning.withOpacity(0.15)
                            : c.primary.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: AssetLogo(
                      keyOrSymbol: widget.item.displayAsset,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Amount + details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount + status
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${_amtFmt.format(widget.item.amount)} ${widget.item.displayAsset}',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusBadge(c, isLocked, isExpired),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Recipient info
                        Row(
                          children: [
                            Icon(
                              LucideIcons.arrowUpRight,
                              size: 11,
                              color: c.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'To',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (_hasSavedName) ...[
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _recipientColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    _recipient!.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: _recipientColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _recipient!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ] else
                              Flexible(
                                child: Text(
                                  widget.item.shortSponsor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Time info
                        if (widget.item.unlockTime != null || widget.item.expiryTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _compactTimeInfo(c, isLocked, isExpired),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Action button
                  _buildActionButton(c, isExpired),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(AppColor c, bool isLocked, bool isExpired) {
    late final Color color;
    late final String label;
    late final IconData icon;

    if (isExpired) {
      color = c.warning;
      label = 'Reclaimable';
      icon = LucideIcons.undo2;
    } else if (isLocked) {
      color = c.warning;
      label = 'Locked';
      icon = LucideIcons.lock;
    } else {
      color = c.primary;
      label = 'Active';
      icon = LucideIcons.checkCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactTimeInfo(AppColor c, bool isLocked, bool isExpired) {
    final items = <Widget>[];

    // Unlock time
    if (widget.item.unlockTime != null && !isExpired) {
      final remaining = widget.item.unlockTimeRemaining;
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? LucideIcons.clock : LucideIcons.unlock,
              size: 10,
              color: isLocked ? c.warning : c.success,
            ),
            const SizedBox(width: 3),
            Text(
              remaining ?? _dateFmt.format(widget.item.unlockTime!.toLocal()),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Expiry time
    if (widget.item.expiryTime != null) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(width: 8));
        items.add(
          Container(
            width: 2,
            height: 2,
            decoration: BoxDecoration(
              color: c.textSecondary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
        );
        items.add(const SizedBox(width: 8));
      }

      final remaining = widget.item.expiryTimeRemaining;
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? LucideIcons.xCircle : LucideIcons.timerOff,
              size: 10,
              color: isExpired ? c.error : c.warning,
            ),
            const SizedBox(width: 3),
            Text(
              remaining ?? _dateFmt.format(widget.item.expiryTime!.toLocal()),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: items,
    );
  }

  Widget _buildActionButton(AppColor c, bool isExpired) {
    if (widget.claiming) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: c.primary,
        ),
      );
    }

    // Reclaimable after expiry
    if (isExpired) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.warning, c.warning.withOpacity(0.85)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: c.warning.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onClaim,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.undo2, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Reclaim',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Active - no action needed
    return const SizedBox.shrink();
  }
}