// lib/features/claimable/view/widgets/claimable_card.dart
import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/asset/asset_logo.dart';
import 'package:next_fi/features/claimable/model/claimable_item.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'package:next_fi/features/wallet_home/model/recipient_address_model.dart';

class ClaimableCard extends StatefulWidget {
  final ClaimableItem item;
  final bool claiming;
  final VoidCallback onClaim;

  const ClaimableCard({
    super.key,
    required this.item,
    required this.claiming,
    required this.onClaim,
  });

  @override
  State<ClaimableCard> createState() => _ClaimableCardState();
}

class _ClaimableCardState extends State<ClaimableCard> {
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
  void didUpdateWidget(ClaimableCard oldWidget) {
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
  Color get _recipientColor =>
      _recipient != null ? Color(_recipient!.color) : AppColor.of(context).textSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final isLocked = widget.item.unlockTime != null && !widget.item.canClaimNow;
    final isExpired =
        widget.item.expiryTime != null &&
        DateTime.now().isAfter(widget.item.expiryTime!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? c.error.withValues(alpha: 0.15)
              : widget.item.canClaimNow
              ? c.primary.withValues(alpha: 0.15)
              : c.border.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.item.canClaimNow
                  ? c.primary.withValues(alpha: 0.1)
                  : c.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.item.canClaimNow
                    ? c.primary.withValues(alpha: 0.2)
                    : c.border.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: AssetLogo(keyOrSymbol: widget.item.displayAsset, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_amtFmt.format(widget.item.amount)} ${widget.item.displayAsset}',
                        style: TextStyle(
                          color: isExpired ? c.textSecondary : c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: isExpired
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(c, isLocked, isExpired),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      LucideIcons.arrowDownLeft,
                      size: 12,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'From',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_hasSavedName) ...[
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _recipientColor.withValues(alpha: 0.15),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
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
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.item.unlockTime != null ||
                    widget.item.expiryTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _compactTimeInfo(c, isLocked, isExpired),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildActionButton(c, isExpired),
        ],
      ),
    );
  }

  Widget _statusBadge(AppColor c, bool isLocked, bool isExpired) {
    late final Color color;
    late final String label;
    late final IconData icon;

    if (isExpired) {
      color = c.error;
      label = 'Expired';
      icon = LucideIcons.xCircle;
    } else if (isLocked) {
      color = c.warning;
      label = 'Locked';
      icon = LucideIcons.lock;
    } else {
      color = c.success;
      label = 'Ready';
      icon = LucideIcons.checkCircle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactTimeInfo(AppColor c, bool isLocked, bool isExpired) {
    final items = <Widget>[];

    if (widget.item.unlockTime != null && !isExpired) {
      final remaining = widget.item.unlockTimeRemaining;
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? LucideIcons.clock : LucideIcons.unlock,
              size: 11,
              color: isLocked ? c.warning : c.success,
            ),
            const SizedBox(width: 4),
            Text(
              remaining ?? _dateFmt.format(widget.item.unlockTime!.toLocal()),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.item.expiryTime != null) {
      if (items.isNotEmpty) {
        items.add(const SizedBox(width: 8));
        items.add(
          Text('•', style: TextStyle(color: c.textSecondary, fontSize: 11)),
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
              size: 11,
              color: isExpired ? c.error : c.warning,
            ),
            const SizedBox(width: 4),
            Text(
              remaining ?? _dateFmt.format(widget.item.expiryTime!.toLocal()),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Row(children: items);
  }

  Widget _buildActionButton(AppColor c, bool isExpired) {
    if (widget.claiming) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
      );
    }

    if (!isExpired && widget.item.canClaimNow) {
      return SizedBox(
        height: 36,
        child: AppElevatedButton(
          onPressed: widget.onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Claim',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
