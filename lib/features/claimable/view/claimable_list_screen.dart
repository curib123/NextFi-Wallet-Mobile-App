// lib/features/claimable/view/claimable_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';

import 'package:next_fi/features/claimable/view_model/claimable_vm.dart';
import 'package:next_fi/features/claimable/view/claimable_create_screen.dart';
import 'package:next_fi/features/claimable/view/widgets/claimable_card.dart';
import 'package:next_fi/features/claimable/view/widgets/claimable_empty.dart';

/// Screen displaying all claimable balances for the current account.
///
/// Features:
/// - Two tabs: Received (can claim) and Sent (created by user)
/// - List of all claimable balances (ready and locked)
/// - Pull-to-refresh functionality
/// - Summary chips showing counts
/// - Floating action button to create new claimable balance
class ClaimableListScreen extends StatefulWidget {
  const ClaimableListScreen({super.key});

  @override
  State<ClaimableListScreen> createState() => _ClaimableListScreenState();
}

class _ClaimableListScreenState extends State<ClaimableListScreen>
    with SingleTickerProviderStateMixin {
  bool _booted = false;
  String? _claimingId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<ClaimableVM>().setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;

    // Initialize on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClaimableVM>().init();
    });

    _booted = true;
  }

  /// Refresh the claimable balances list
  Future<void> _refresh() async {
    if (!mounted) return;
    await context.read<ClaimableVM>().refresh();
  }

  /// Claim a specific balance by ID
  Future<void> _claim(String balanceId) async {
    setState(() => _claimingId = balanceId);

    try {
      final txHash = await context.read<ClaimableVM>().claim(balanceId);
      if (!mounted) return;

      HapticFeedback.mediumImpact();

      showAppAlert(
        context,
        type: AppAlertType.success,
        title: 'Claimed successfully',
        subtitle: 'Transaction: $txHash',
        primaryText: 'Copy TxID',
        onPrimary: () async {
          await Clipboard.setData(ClipboardData(text: txHash));
        },
      );
    } catch (e) {
      if (!mounted) return;

      showAppAlert(
        context,
        type: AppAlertType.error,
        title: 'Claim failed',
        subtitle: '$e',
        primaryText: 'OK',
      );
    } finally {
      if (mounted) {
        setState(() => _claimingId = null);
      }
    }
  }

  /// Navigate to create claimable balance screen
  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClaimableCreateScreen(),
      ),
    ).then((_) {
      // Refresh list when returning from create screen
      if (mounted) {
        context.read<ClaimableVM>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = context.watch<ClaimableVM>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Claimable Balances',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        actions: [
          // Refresh button
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
              LucideIcons.refreshCcw,
              size: 20,
              color: c.textPrimary,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _refresh();
            },
          ),
        ],
        bottom: vm.loading || vm.error != null
            ? null
            : TabBar(
          controller: _tabController,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.inbox, size: 16),
                  const SizedBox(width: 6),
                  Text('Received'),
                  if (vm.receivedTotalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${vm.receivedTotalCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.send, size: 16),
                  const SizedBox(width: 6),
                  Text('Sent'),
                  if (vm.sentUnclaimedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${vm.sentUnclaimedCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(c, vm),
      floatingActionButton: _buildFAB(c, vm),
    );
  }

  /// Build the main body based on current state
  Widget _buildBody(AppColor c, ClaimableVM vm) {
    if (vm.loading) {
      return const PageLoader();
    }

    if (vm.error != null) {
      return _buildError(c, vm);
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildReceivedTab(c, vm),
        _buildSentTab(c, vm),
      ],
    );
  }

  /// Build received tab content
  Widget _buildReceivedTab(AppColor c, ClaimableVM vm) {
    if (vm.receivedItems.isEmpty) {
      return ClaimableEmpty(
        onCreate: _openCreate,
        message: 'No claimable balances',
        description: 'When someone sends you a claimable balance, '
            'it will appear here. You can also create one yourself.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: _buildList(c, vm.receivedItems, isReceived: true),
    );
  }

  /// Build sent tab content
  Widget _buildSentTab(AppColor c, ClaimableVM vm) {
    if (vm.sentItems.isEmpty) {
      return ClaimableEmpty(
        onCreate: _openCreate,
        message: 'No sent balances',
        description: 'Claimable balances you create will appear here. '
            'You can track their status and see when they\'re claimed.',
        icon: LucideIcons.send,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: _buildList(c, vm.sentItems, isReceived: false),
    );
  }

  /// Build error state
  Widget _buildError(AppColor c, ClaimableVM vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 32,
              color: c.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              vm.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _refresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the list of claimable balances
  Widget _buildList(
      AppColor c,
      List<dynamic> items, {
        required bool isReceived,
      }) {
    final vm = context.watch<ClaimableVM>();
    final readyCount = items.where((i) => i.canClaimNow).length;
    final lockedCount = items.where((i) =>
    i.unlockTime != null && !i.canClaimNow
    ).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Summary chips
        if (items.isNotEmpty) ...[
          _buildSummary(c, readyCount, lockedCount, isReceived),
          const SizedBox(height: 14),
        ],

        // Cards
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          ClaimableCard(
            item: items[i],
            claiming: _claimingId == items[i].balanceId,
            onClaim: () => _claim(items[i].balanceId),
            isSent: !isReceived,
          ),
        ],
      ],
    );
  }

  /// Build summary chips showing counts
  Widget _buildSummary(
      AppColor c,
      int readyCount,
      int lockedCount,
      bool isReceived,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (readyCount > 0)
          _summaryChip(
            c,
            isReceived
                ? '$readyCount ready to claim'
                : '$readyCount unlocked',
            c.success,
            LucideIcons.checkCircle,
          ),
        if (lockedCount > 0)
          _summaryChip(
            c,
            '$lockedCount locked',
            c.warning,
            LucideIcons.lock,
          ),
      ],
    );
  }

  /// Build a single summary chip
  Widget _summaryChip(
      AppColor c,
      String label,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build floating action button
  Widget? _buildFAB(AppColor c, ClaimableVM vm) {
    if (vm.loading || vm.error != null) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _openCreate,
      backgroundColor: c.primary,
      elevation: 2,
      child: const Icon(
        LucideIcons.plus,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}