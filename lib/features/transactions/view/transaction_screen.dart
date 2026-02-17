import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/common/components/drawer/appdrawer.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/common/components/emptywidgets/empty_state.dart';
import 'package:next_fi/common/components/button/CustomButton.dart';
import 'package:next_fi/common/components/loader/page_loader.dart';

import 'package:next_fi/features/transactions/model/tx.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';

import 'widgets/transaction_filter_chips.dart';
import 'widgets/tx_details_sheet.dart';
import 'widgets/incoming_chip.dart';
import 'widgets/transaction_tile.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Tx>? _incomingUiSub;

  WalletHomeVM? _walletVm;
  VoidCallback? _walletListener;
  String? _lastBoundAddr;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');
  final List<IncomingChipData> _incomingChips = [];

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (!mounted || !pos.hasPixels) return;

      final txvm = context.read<TransactionsVM>();
      if (pos.pixels >= pos.maxScrollExtent - 200 &&
          !txvm.state.loadingMore &&
          txvm.state.hasMore) {
        txvm.fetch(loadMore: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final walletNow = context.read<WalletHomeVM>();
      final txvm = context.read<TransactionsVM>();

      if (!identical(walletNow, _walletVm)) {
        if (_walletVm != null && _walletListener != null) {
          _walletVm!.removeListener(_walletListener!);
        }
        _walletVm = walletNow;

        _walletListener ??= () {
          final addr = _walletVm!.state.address;
          if (addr != _lastBoundAddr) {
            _lastBoundAddr = addr;
            txvm.bindToAddress(addr);
          }
        };

        _walletVm!.addListener(_walletListener!);
        _walletListener!();
      }

      _incomingUiSub ??= txvm.incomingStream.listen((tx) {
        if (!mounted) return;

        final colors = AppColor.of(context);
        final asset = (tx['asset'] ?? 'XLM').toString();
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        _pushIncomingChip(
          text: 'Incoming ${amount.toStringAsFixed(6)} $asset',
          color: colors.success,
          icon: LucideIcons.arrowDownCircle,
        );

        final ctl = showAppAlert(
          context,
          type: AppAlertType.info,
          title: 'Incoming $asset',
          subtitle:
              'You received ${amount.toStringAsFixed(6)} $asset. Tap below to view details.',
          primaryText: 'View',
          barrierDismissible: true,
          onPrimary: () {
            final peerAddr = (tx['from'] ?? '').toString().trim();
            showTxDetailsBottomSheet(
              context: context,
              tx: tx,
              peerAddr: peerAddr,
              isIncoming: true,
            );
          },
        );

        Timer(const Duration(seconds: 5), () {
          if (mounted) ctl;
        });
      });
    });
  }

  @override
  void dispose() {
    _incomingUiSub?.cancel();
    _incomingUiSub = null;

    if (_walletVm != null && _walletListener != null) {
      _walletVm!.removeListener(_walletListener!);
    }
    _walletVm = null;
    _walletListener = null;

    _scrollController.dispose();
    super.dispose();
  }

  void _pushIncomingChip({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    final chip = IncomingChipData(
      text: text,
      color: color,
      icon: icon ?? LucideIcons.arrowDownCircle,
    );
    setState(() => _incomingChips.add(chip));
    chip.timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _incomingChips.remove(chip));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final vm = context.watch<TransactionsVM>();
    final recipProv = context.watch<RecipientAddressVM>();

    void attachRecipientMetaTo(List<Tx> list) {
      if (recipProv.loading) return;
      for (final tx in list) {
        final direction = (tx['direction'] ?? 'other').toString();
        final isIncoming = direction == 'in';
        final peerAddr =
            (isIncoming ? (tx['from'] ?? '') : (tx['to'] ?? '')).toString().trim();
        if (peerAddr.isEmpty) continue;
        final rec = recipProv.byAddress(peerAddr);
        tx['recName'] = rec?.name;
        tx['recColor'] = rec?.color;
      }
    }

    final visibleTxs = [...vm.state.visibleTxs];
    attachRecipientMetaTo(visibleTxs);
    final showLoaderRow = vm.state.loadingMore && vm.state.filter == TxFilter.all;

    Widget content;
    if (vm.state.loading && vm.state.txs.isEmpty) {
      content = const PageLoader();
    } else if (vm.state.errorMsg != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState.error(
                title: 'Could not load transactions',
                message: vm.state.errorMsg!,
                primaryActionLabel: null,
                onPrimaryAction: null,
                context: context,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Retry',
                icon: LucideIcons.refreshCw,
                onPressed: vm.resetAndFetch,
                type: ButtonType.filled,
              ),
            ],
          ),
        ),
      );
    } else if (vm.state.txs.isEmpty) {
      final msg = vm.state.accountMissing
          ? 'This wallet is new or not yet funded on-chain. Once you receive your first XLM or USDC, your transactions will appear here.'
          : 'When you send or receive XLM or USDC, they will appear here.';
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState.noData(
                title: 'No transactions yet',
                message: msg,
                primaryActionLabel: null,
                onPrimaryAction: null,
                context: context,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Refresh',
                icon: LucideIcons.refreshCw,
                onPressed: vm.resetAndFetch,
                type: ButtonType.outlined,
              ),
            ],
          ),
        ),
      );
    } else if (vm.state.txs.isNotEmpty && visibleTxs.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState.noData(
                title: 'No matching transactions',
                message: 'Try switching filters to All, Receive, or Send.',
                primaryActionLabel: null,
                onPrimaryAction: null,
                context: context,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Clear Filter',
                icon: LucideIcons.filterX,
                onPressed: () => vm.setFilter(TxFilter.all),
                type: ButtonType.outlined,
              ),
            ],
          ),
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: vm.resetAndFetch,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: visibleTxs.length + (showLoaderRow ? 1 : 0),
          itemBuilder: (context, index) {
            if (showLoaderRow && index >= visibleTxs.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: ModernFintechLoader(
                    size: 24,
                    speed: const Duration(milliseconds: 1200),
                    color: colors.textPrimary,
                  ),
                ),
              );
            }

            final tx = visibleTxs[index];
            return TransactionTile(
              colors: colors,
              tx: tx,
              recipProv: recipProv,
              listFormat: _listFmt,
              onTap: () {
                final direction = (tx['direction'] ?? 'other').toString();
                final isIncoming = direction == 'in';
                final peerAddr =
                    (isIncoming ? (tx['from'] ?? '') : (tx['to'] ?? ''))
                        .toString()
                        .trim();

                showTxDetailsBottomSheet(
                  context: context,
                  tx: tx,
                  peerAddr: peerAddr,
                  isIncoming: isIncoming,
                );
              },
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TransactionFilterChips(colors: colors, vm: vm),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: content,
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _incomingChips
                    .map(
                      (c) => AnimatedSlide(
                        key: ValueKey(c.id),
                        duration: const Duration(milliseconds: 250),
                        offset: const Offset(0, 0),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1.0,
                          child: IncomingChipBadge(
                            chip: c,
                            surface: colors.surface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
