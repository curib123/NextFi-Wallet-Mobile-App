// lib/features/activity/view/widgets/activity_notification.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/activity_log.dart';

/// Toast-style notification for activity updates
class ActivityNotification extends StatelessWidget {
  final ActivityLog activity;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const ActivityNotification({
    super.key,
    required this.activity,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(colors),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon
                _buildStatusIcon(colors),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        activity.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),

                      // Description
                      if (activity.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          activity.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Error message
                      if (activity.hasError) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            activity.errorMessage!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],

                      // Transaction hash
                      if (activity.isActionable) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.externalLink,
                              size: 12,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.shortTxHash ?? 'View on explorer',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Dismiss button
                if (onDismiss != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AppColor colors) {
    IconData iconData;
    Color iconColor;

    switch (activity.status) {
      case ActivityStatus.completed:
        iconData = LucideIcons.checkCircle;
        iconColor = Colors.green;
        break;
      case ActivityStatus.failed:
        iconData = LucideIcons.alertCircle;
        iconColor = Colors.red;
        break;
      case ActivityStatus.processing:
        iconData = LucideIcons.loader2;
        iconColor = colors.primary;
        break;
      case ActivityStatus.pending:
        iconData = LucideIcons.clock;
        iconColor = Colors.orange;
        break;
      case ActivityStatus.cancelled:
        iconData = LucideIcons.xCircle;
        iconColor = colors.textSecondary;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }

  Color _getBorderColor(AppColor colors) {
    switch (activity.status) {
      case ActivityStatus.completed:
        return Colors.green.withOpacity(0.3);
      case ActivityStatus.failed:
        return Colors.red.withOpacity(0.3);
      case ActivityStatus.processing:
        return colors.primary.withOpacity(0.3);
      case ActivityStatus.pending:
        return Colors.orange.withOpacity(0.3);
      case ActivityStatus.cancelled:
        return colors.textSecondary.withOpacity(0.3);
    }
  }
}

/// Manager for showing activity notifications as overlays
class ActivityNotificationManager {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show a notification overlay
  static void show(
      BuildContext context,
      ActivityLog activity, {
        Duration duration = const Duration(seconds: 4),
        VoidCallback? onTap,
      }) {
    // Remove existing notification
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 0,
        right: 0,
        child: ActivityNotification(
          activity: activity,
          onDismiss: dismiss,
          onTap: onTap ?? () async {
            dismiss();
            if (activity.stellarExpertUrl != null) {
              final uri = Uri.parse(activity.stellarExpertUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, dismiss);
  }

  /// Dismiss current notification
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    _currentEntry?.remove();
    _currentEntry = null;
  }
}