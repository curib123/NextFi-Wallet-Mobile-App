import 'dart:async';
import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/common/components/AppAlert.dart';
import 'package:next_fi/common/components/empty_state.dart';
import 'package:next_fi/features/transactions/model/tx.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_home/view_model/recipient_address_vm.dart';
import 'widgets/transaction_filter_chips.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/tx_details_sheet.dart';
import 'widgets/incoming_chip.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Tx>? _incomingUiSub;

  // bind to wallet address changes
  VoidCallback? _walletListener;
  String? _lastBoundAddr;

  static final DateFormat _listFmt = DateFormat('MMM d, h:mm a');

  final List<IncomingChipData> _incomingChips = [];

  @override
  void initState() {
    super.initState();

    // infinite scroll → load more
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (!mounted || !pos.hasPixels) return;
      final vm = context.read<TransactionsVM>();
      if (pos.pixels >= pos.maxScrollExtent - 200 &&
          !vm.state.loadingMore &&
          vm.state.hasMore) {
        vm.fetch(loadMore: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final wallet = context.read<WalletHomeVM>();
      final txvm = context.read<TransactionsVM>();

      _walletListener ??= () {
        final addr = wallet.state.address;
        if (addr != _lastBoundAddr) {
          _lastBoundAddr = addr;
          txvm.bindToAddress(addr);
        }
      };

      wallet.removeListener(_walletListener!);
      wallet.addListener(_walletListener!);
      _walletListener!(); // initial bind

      // subscribe once for incoming UI chips/toasts
      _incomingUiSub ??= txvm.incomingStream.listen((tx) {
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
            const isIncoming = true;
            showTxDetailsBottomSheet(
              context: context,
              tx: tx,
              peerAddr: peerAddr,
              isIncoming: isIncoming,
            );
          },
        );
        Timer(const Duration(seconds: 5), () {
          if (mounted) ctl.close();
        });
      });
    });
  }

  @override
  void dispose() {
    _incomingUiSub?.cancel();

    final wallet = mounted ? context.read<WalletHomeVM>() : null;
    if (wallet != null && _walletListener != null) {
      wallet.removeListener(_walletListener!);
    }

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

    // Attach contact meta (UI-only; VM state remains pure)
    void attachRecipientMetaTo(List<Tx> list) {
      if (recipProv.loading) return;
      for (final tx in list) {
        final direction = (tx['direction'] ?? 'other').toString();
        final isIncoming = direction == 'in';
        final peerAddr =
        (isIncoming ? (tx['from'] ?? '') : (tx['to'] ?? ''))
            .toString()
            .trim();
        if (peerAddr.isEmpty) continue;
        final rec = recipProv.byAddress(peerAddr);
        tx['recName'] = rec?.name;
        tx['recColor'] = rec?.color;
      }
    }

    final visibleTxs = [...vm.state.visibleTxs];
    attachRecipientMetaTo(visibleTxs);
    final showLoaderRow =
        vm.state.loadingMore && vm.state.filter == TxFilter.all;

    Widget content;
    if (vm.state.loading && vm.state.txs.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (vm.state.errorMsg != null) {
      content = Center(
        child: EmptyState.error(
          title: 'Couldn’t load transactions',
          message: vm.state.errorMsg!,
          primaryActionLabel: 'Retry',
          onPrimaryAction: vm.resetAndFetch,
          context: context,
        ),
      );
    } else if (vm.state.txs.isEmpty) {
      final msg = vm.state.accountMissing
          ? 'This wallet is new or not yet funded on-chain. Once you receive your first XLM or USDC, your transactions will appear here.'
          : 'When you send or receive XLM or USDC, they’ll appear here.';
      content = Center(
        child: EmptyState.noData(
          title: 'No transactions yet',
          message: msg,
          primaryActionLabel: 'Refresh',
          onPrimaryAction: vm.resetAndFetch,
          context: context,
        ),
      );
    } else if (vm.state.txs.isNotEmpty && visibleTxs.isEmpty) {
      content = Center(
        child: EmptyState.noData(
          title: 'No matching transactions',
          message: 'Try switching filters to All, Receive, or Send.',
          primaryActionLabel: 'Clear Filter',
          onPrimaryAction: () => vm.setFilter(TxFilter.all),
          context: context,
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
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.surface,
        title: const Text('Transactions',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
          // top-center incoming chips overlay
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _incomingChips
                    .map((c) => AnimatedSlide(
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
                ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
