// lib/features/claimable/view/claimable_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer_button.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer.dart';

import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/loader/page_loader.dart';
import 'package:next_fi/core/widgets/modal/token_chooser.dart';

import 'package:next_fi/features/claimable/presentation/viewmodels/claimable_vm.dart';
import 'package:next_fi/features/claimable/presentation/screens/claimable_create_screen.dart';
import 'package:next_fi/features/claimable/presentation/widgets/claimable_card.dart';
import 'package:next_fi/features/claimable/presentation/widgets/sent_claimable_card.dart';
import 'package:next_fi/features/claimable/presentation/widgets/claimable_empty.dart';

class ClaimableListScreen extends ConsumerStatefulWidget {
  const ClaimableListScreen({super.key});

  @override
  ConsumerState<ClaimableListScreen> createState() => _ClaimableListScreenState();
}

class _ClaimableListScreenState extends ConsumerState<ClaimableListScreen>
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
        ref.read(claimableVmProvider).setTab(_tabController.index);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(claimableVmProvider).init();
    });

    _booted = true;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await ref.read(claimableVmProvider).refresh();
  }

  Future<void> _claim(String balanceId) async {
    setState(() => _claimingId = balanceId);

    try {
      final txHash = await ref.read(claimableVmProvider).claim(balanceId);
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

  void _openCreate() {
    final vm = ref.read(claimableVmProvider);
    showTokenSelector(
      context,
      vm.accountId ?? '',
      vm.xlmBalance,
      vm.usdcBalance,
      title: 'Select Asset to Lock',
      screenBuilder: (address, token, balance) {
        return ClaimableCreateScreen(initialAsset: token.toUpperCase());
      },
    ).then((_) {
      if (mounted) {
        ref.read(claimableVmProvider).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColor.of(context);
    final vm = ref.watch(claimableVmProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(c, vm),
            if (!vm.loading && vm.error == null) _buildTabBar(c, vm),
            Expanded(child: _buildBody(c, vm)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(c, vm),
    );
  }

  Widget _buildAppBar(AppColor c, ClaimableVM vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppDrawerButton(
                colors: c,
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Claimable Balances',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _refresh();
            },
            icon: Icon(LucideIcons.refreshCcw, color: c.textPrimary),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppColor c, ClaimableVM vm) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: c.primary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.inbox, size: 16),
                const SizedBox(width: 8),
                const Text('Received'),
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
                        fontWeight: FontWeight.w700,
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
                const SizedBox(width: 8),
                const Text('Sent'),
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
                        fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildBody(AppColor c, ClaimableVM vm) {
    if (vm.loading) {
      return const PageLoader();
    }

    if (vm.error != null) {
      return _buildError(c, vm);
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildReceivedTab(c, vm), _buildSentTab(c, vm)],
    );
  }

  Widget _buildReceivedTab(AppColor c, ClaimableVM vm) {
    if (vm.receivedItems.isEmpty) {
      return ClaimableEmpty(
        onCreate: _openCreate,
        message: 'No claimable balances',
        description:
            'When someone sends you a claimable balance, '
            'it will appear here. You can also create one yourself.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.primary,
      child: _buildList(c, vm.receivedItems, isReceived: true),
    );
  }

  Widget _buildSentTab(AppColor c, ClaimableVM vm) {
    if (vm.sentItems.isEmpty) {
      return ClaimableEmpty(
        onCreate: _openCreate,
        message: 'No sent balances',
        description:
            'Claimable balances you create will appear here. '
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
              style: TextStyle(color: c.error, fontSize: 14),
            ),
            const SizedBox(height: 16),
            AppOutlinedButton(
              onPressed: _refresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.border.withValues(alpha: 0.2)),
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

  Widget _buildList(
    AppColor c,
    List<dynamic> items, {
    required bool isReceived,
  }) {
    final readyCount = items.where((i) => i.canClaimNow).length;
    final lockedCount = items
        .where((i) => i.unlockTime != null && !i.canClaimNow)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (items.isNotEmpty) ...[
          _buildSummary(c, readyCount, lockedCount, isReceived),
          const SizedBox(height: 14),
        ],
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          if (isReceived)
            ClaimableCard(
              item: items[i],
              claiming: _claimingId == items[i].balanceId,
              onClaim: () => _claim(items[i].balanceId),
            )
          else
            SentClaimableCard(
              item: items[i],
              claiming: _claimingId == items[i].balanceId,
              onClaim: () => _claim(items[i].balanceId),
            ),
        ],
      ],
    );
  }

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
            isReceived ? '$readyCount ready to claim' : '$readyCount unlocked',
            c.success,
            LucideIcons.checkCircle,
          ),
        if (lockedCount > 0)
          _summaryChip(c, '$lockedCount locked', c.warning, LucideIcons.lock),
      ],
    );
  }

  Widget _summaryChip(AppColor c, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
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
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFAB(AppColor c, ClaimableVM vm) {
    if (vm.loading || vm.error != null) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _openCreate,
      backgroundColor: c.primary,
      elevation: 2,
      child: Icon(LucideIcons.plus, color: c.onPrimary, size: 22),
    );
  }
}


