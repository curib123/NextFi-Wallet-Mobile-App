import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/features/receive/view/receive_screen.dart';
import 'package:next_fi/features/send/view/send_screen.dart';
import 'package:next_fi/features/swap/view/swap_screen.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/wallet_home/view/widgets/asset_widget.dart';
import 'package:next_fi/features/wallet_home/view/widgets/build_tab_bar.dart';
import 'package:next_fi/features/wallet_home/view/widgets/header_section.dart';
import 'package:next_fi/features/wallet_home/view/widgets/incoming_hints_strip.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/wallet_home/view/widgets/tab_keep_alive.dart';
import 'package:next_fi/features/wallet_home/view/widgets/top_bar.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';

import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/common/components/token_chooser.dart';
import 'package:next_fi/common/components/AppAlert.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});
  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _livePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  final Map<String, AppAlertController> _hintAlertCtrls = <String, AppAlertController>{};
  AppAlertController? _bootBalancesCtl;
  StreamSubscription<WalletHomeUiEvent>? _uiSub;

  // First open: no counting animation; enabled once BootBalancesReady arrives.
  bool _animateTotal = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<WalletHomeVM>();
      final txVm = context.read<TransactionsVM>();

      _uiSub = vm.uiEvents.listen(_onUiEvent);
      vm.attachConfirmedTxStream(txVm.incomingStream);

      unawaited(vm.boot());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePulse.dispose();

    _uiSub?.cancel();
    _uiSub = null;

    for (final ctl in _hintAlertCtrls.values) {
      ctl.close();
    }
    _hintAlertCtrls.clear();

    _bootBalancesCtl?.close();
    _bootBalancesCtl = null;

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vm = context.read<WalletHomeVM>();
    if (state == AppLifecycleState.resumed) {
      vm.onResumed();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      vm.onPausedOrInactive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colors = AppColor.of(context);
    final vm = context.watch<WalletHomeVM>();
    final s = vm.state;

    final currency = context.watch<CurrencyVM>();
    final assetsVM = context.watch<AssetVM>();
    final stellar = context.read<StellarWalletService>();

    final currencyFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fxXlm = currency.xlmToFiat(s.xlm);
    final fxUsdc = currency.usdcToFiat(s.usdc);
    final totalFiat = (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

    final assetList = assetsVM.assets;
    final logosById = {
      for (final a in assetList) a.id: (a.primaryLogo.isNotEmpty ? a.primaryLogo : assetsVM.logoFor(a.symbol)),
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: RefreshIndicator.adaptive(
            onRefresh: () => context.read<WalletHomeVM>().refresh(force: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TopBar(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: HeaderSection(
                      colors: colors,
                      currencyFmt: currencyFmt,
                      loadingBalances: s.loadingBalances,
                      totalFiat: totalFiat,
                      lastBalancesAt: s.lastBalancesAt,
                      onSwap: () => vm.onSwapPressed(),
                      onSend: () => vm.onSendPressed(),
                      onReceive: () => vm.onReceivePressed(),
                      livePulse: _livePulse,
                      incomingStrip: s.hasWallet
                          ? IncomingHintsStrip(
                        colors: colors,
                        stellarAddress: s.address ?? '',
                        incomingHints: s.hints
                            .map((h) => {
                          'hash': h.id,
                          'from': h.from,
                          'to': h.to,
                          'amount': h.amount.toStringAsFixed(6),
                          'assetCode': h.assetCode,
                        })
                            .toList(),
                        onAcknowledge: (tx) => context.read<WalletHomeVM>().ackHint(
                          (tx['hash'] ?? '').toString(),
                        ),
                      )
                          : const SizedBox.shrink(),
                      animateTotal: _animateTotal,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: buildTabBar(colors),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(
                    children: [
                      TabKeepAlive(
                        storageKey: 'assetsTab',
                        child: AssetWidget(
                          colors: colors,
                          assets: assetList,
                          logos: logosById,
                          xlmBalance: s.xlm,
                          usdcBalance: s.usdc,
                          address: s.address ?? '',
                          loading: assetsVM.loading || currency.loading || s.loadingBalances,
                          onItemTap: (token) {
                            vm.onReceivePressed(initialToken: token);
                          },
                          hasUsdcTrustline: stellar.hasUsdcTrustline(s.address ?? ''),
                        ),
                      ),
                      TabKeepAlive(
                        storageKey: 'recipientsTab',
                        child: RecipientListWidget(
                          colors: colors,
                          xlmBalance: s.xlm,
                          usdcBalance: s.usdc,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────── Event handling (UI side effects) ─────────────────────
  void _onUiEvent(WalletHomeUiEvent e) async {
    if (!mounted) return;

    SnackBarType _mapSeverity(UiSeverity s) {
      switch (s) {
        case UiSeverity.success:
          return SnackBarType.success;
        case UiSeverity.warning:
          return SnackBarType.warning;
        case UiSeverity.error:
          return SnackBarType.error;
        case UiSeverity.info:
          return SnackBarType.info;
      }
    }

    final vm = context.read<WalletHomeVM>();

    if (e is ShowToastEvent) {
      showFloatingSnackBar(context, message: e.message, type: _mapSeverity(e.severity));
      return;
    }

    if (e is BootBalancesLoading) {
      if (mounted) setState(() => _animateTotal = false);
      _bootBalancesCtl ??= showAppAlert(
        context,
        type: AppAlertType.loading,
        title: 'Fetching balances',
        subtitle: 'Calculating your total…',
        barrierDismissible: false,
      );
      return;
    }

    if (e is BootBalancesReady) {
      if (!mounted) return;
      final currency = context.read<CurrencyVM>();
      final currencyFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
      final fxXlm = currency.xlmToFiat(e.xlm);
      final fxUsdc = currency.usdcToFiat(e.usdc);
      final totalFiat = (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

      // Update, then immediately close (no timer) and enable counting animation.
      _bootBalancesCtl?.update(
        AppAlertType.success,
        title: 'Balances ready',
        subtitle: 'Total ${currencyFmt.format(totalFiat)}',
      );
      _bootBalancesCtl?.close();
      _bootBalancesCtl = null;

      if (mounted) setState(() => _animateTotal = true);
      return;
    }

    if (e is StartSendFlow) {
      await showTokenSelector(
        context,
        e.address,
        e.xlm,
        e.usdc,
        title: 'Send Coin',
        screenBuilder: (address, token, balance) =>
            SendScreen(address: address, token: token, balance: balance),
      );
      if (!mounted) return;
      await vm.refresh(force: true);
      return;
    }

    if (e is StartReceiveFlow) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiveScreen(
            address: e.address,
            xlmBalance: e.xlm,
            usdcBalance: e.usdc,
            initialToken: e.initialToken ?? 'XLM',
          ),
        ),
      );
      return;
    }

    if (e is NavigateToSwap) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SwapScreen()),
      );
      return;
    }

    if (e is IncomingHintAddedEvent) {
      _showPendingAlertForHint(e.hint);
      return;
    }

    if (e is TransactionConfirmedEvent) {
      final ctl = _hintAlertCtrls.remove(e.hash);
      if (ctl != null) {
        ctl.update(
          AppAlertType.success,
          title: 'Received ${e.amount.toStringAsFixed(6)} ${e.asset}',
          subtitle: 'Confirmed on-chain.',
          primaryText: 'Done',
        );
        vm.ackHint(e.hash);
      }
      return;
    }

    if (e is HintAcknowledgedEvent) {
      final ctl = _hintAlertCtrls.remove(e.id);
      ctl?.close();
      return;
    }
  }

  void _showPendingAlertForHint(dynamic h) {
    if (!mounted) return;
    final vm = context.read<WalletHomeVM>();
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Incoming ${h.amount.toStringAsFixed(6)} ${h.assetCode}',
      subtitle: 'From ${_short(h.from)} • Pending confirmation…',
      primaryText: 'Acknowledge',
      onPrimary: () => vm.ackHint(h.id),
      barrierDismissible: true,
    );
    _hintAlertCtrls[h.id] = ctl;
  }

  String _short(String addr) {
    if (addr.isEmpty) return '—';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
}
