// lib/features/activity/view/activity_screen.dart
import 'package:flutter/material.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../model/activity_log.dart';
import '../view_model/activity_log_vm.dart';

/// Activity/Audit Trail Screen
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.textPrimary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Failed'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showFilterMenu(context),
            icon: const Icon(LucideIcons.filter),
          ),
          IconButton(
            onPressed: () => _showOptionsMenu(context),
            icon: const Icon(LucideIcons.moreVertical),
          ),
        ],
      ),
      body: Consumer<ActivityLogVM>(
        builder: (context, vm, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildActivityList(vm, vm.logs),
              _buildActivityList(vm, vm.pendingActivities),
              _buildActivityList(vm, vm.failedActivities),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityList(ActivityLogVM vm, List<ActivityLog> activities) {
    if (activities.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupByDate(activities);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh logic if needed
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          final dateLabel = entry.key;
          final logs = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColor.of(context).textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Activities for this date
              ...logs.map((log) => ActivityListItem(
                activity: log,
                onTap: () => _showActivityDetails(log),
                onRetry: log.status == ActivityStatus.failed
                    ? () => _retryActivity(log)
                    : null,
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = AppColor.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.inbox,
            size: 64,
            color: colors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<ActivityLog>> _groupByDate(List<ActivityLog> activities) {
    final grouped = <String, List<ActivityLog>>{};
    for (final activity in activities) {
      final dateKey = _formatDateKey(activity.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(activity);
    }
    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';

    final diff = today.difference(dateOnly).inDays;
    if (diff < 7) return '${diff} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }

  void _showActivityDetails(ActivityLog activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityDetailSheet(activity: activity),
    );
  }

  void _retryActivity(ActivityLog activity) {
    // TODO: Implement retry logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Retry not yet implemented')),
    );
  }

  void _showFilterMenu(BuildContext context) {
    // TODO: Implement filter menu
  }

  void _showOptionsMenu(BuildContext context) {
    final colors = AppColor.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('Clear failed activities'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ActivityLogVM>().clearFailed();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.calendar),
                title: const Text('Clear old completed'),
                subtitle: const Text('Older than 7 days'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ActivityLogVM>().clearOldCompleted(7);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash),
                title: const Text('Clear all'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _confirmClearAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all activities?'),
        content: const Text(
          'This will permanently delete all activity logs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ActivityLogVM>().clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

/// Individual activity list item
class ActivityListItem extends StatelessWidget {
  final ActivityLog activity;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const ActivityListItem({
    super.key,
    required this.activity,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                _buildIcon(colors),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Amount
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (activity.amount != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${activity.amount!.toStringAsFixed(2)} ${activity.asset ?? ''}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getAmountColor(colors),
                              ),
                            ),
                          ],
                        ],
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
                        ),
                      ],

                      // Error message
                      if (activity.hasError) ...[
                        const SizedBox(height: 6),
                        Text(
                          activity.errorMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Time + Status
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            timeago.format(activity.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(colors),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRetry,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    tooltip: 'Retry',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(AppColor colors) {
    IconData iconData;
    Color iconColor;

    switch (activity.status) {
      case ActivityStatus.completed:
        iconData = LucideIcons.checkCircle2;
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

  Widget _buildStatusBadge(AppColor colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        activity.status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (activity.status) {
      case ActivityStatus.completed:
        return Colors.green;
      case ActivityStatus.failed:
        return Colors.red;
      case ActivityStatus.processing:
        return Colors.blue;
      case ActivityStatus.pending:
        return Colors.orange;
      case ActivityStatus.cancelled:
        return Colors.grey;
    }
  }

  Color _getAmountColor(AppColor colors) {
    if (activity.type == ActivityType.receiveXlm ||
        activity.type == ActivityType.receiveUsdc) {
      return Colors.green;
    }
    return colors.textPrimary;
  }
}

/// Activity detail bottom sheet
class ActivityDetailSheet extends StatelessWidget {
  final ActivityLog activity;

  const ActivityDetailSheet({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details
                  if (activity.amount != null)
                    _buildDetailRow(
                      'Amount',
                      '${activity.amount!.toStringAsFixed(7)} ${activity.asset ?? ''}',
                      colors,
                    ),
                  if (activity.fromAddress != null)
                    _buildDetailRow('From', activity.fromAddress!, colors),
                  if (activity.toAddress != null)
                    _buildDetailRow('To', activity.toAddress!, colors),
                  _buildDetailRow(
                    'Time',
                    timeago.format(activity.timestamp),
                    colors,
                  ),
                  _buildDetailRow('Status', activity.status.label, colors),

                  // Error details
                  if (activity.hasError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity.errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                          if (activity.errorAdvice != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              activity.errorAdvice!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Actions
                  if (activity.isActionable) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(activity.stellarExpertUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(LucideIcons.externalLink, size: 18),
                        label: const Text('View on Explorer'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColor colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}