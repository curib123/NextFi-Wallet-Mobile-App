// lib/features/wallet_home/view/wallet_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';
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
import 'package:provider/provider.dart';

import 'package:next_fi/common/components/SnackBar.dart';
import 'package:next_fi/common/components/token_chooser.dart';
import 'package:next_fi/common/components/AppAlert.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});
  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  late final AnimationController _livePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  // Controllers for per-hint and boot alerts
  final Map<String, AppAlertController> _hintAlertCtrls =
  <String, AppAlertController>{};
  AppAlertController? _bootBalancesCtl;

  // Subscriptions
  StreamSubscription<WalletHomeUiEvent>? _uiSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<WalletHomeVM>();

      // Subscribe to VM UI events
      _uiSub = vm.uiEvents.listen(_onUiEvent);

      // Pipe confirmed-transaction stream into VM, if you use TransactionsVM
      final txVm = context.read<TransactionsVM>();
      vm.attachConfirmedTxStream(txVm.incomingStream);

      // Kick off boot (VM will emit UI events for the loader & success)
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
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
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
    final assets = context.watch<AssetVM>();
    final stellar = context.read<StellarWalletService>();

    final currencyFmt =
    NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final fxXlm = currency.xlmToFiat(s.xlm);
    final fxUsdc = currency.usdcToFiat(s.usdc);
    final totalFiat =
        (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

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
                      onSwap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SwapScreen())),
                      onSend: _onSend,
                      onReceive: _onReceive,
                      livePulse: _livePulse,
                      incomingStrip: s.hasWallet
                          ? IncomingHintsStrip(
                        colors: colors,
                        stellarAddress: s.address!,
                        incomingHints: s.hints
                            .map((h) => {
                          'hash': h.id,
                          'from': h.from,
                          'to': h.to,
                          'amount': h.amount.toStringAsFixed(6),
                          'assetCode': h.assetCode,
                        })
                            .toList(),
                        onAcknowledge: (tx) {
                          final String id = (tx['hash'] ?? '').toString();
                          context.read<WalletHomeVM>().ackHint(id);
                          final ctl = _hintAlertCtrls.remove(id);
                          ctl?.close();
                        },
                      )
                          : const SizedBox.shrink(),
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
                          assets: assets.assets,
                          logos: assets.logos,
                          xlmBalance: s.xlm,
                          usdcBalance: s.usdc,
                          address: s.address ?? '',
                          loading: assets.loading ||
                              currency.loading ||
                              s.loadingBalances,
                          onItemTap: (token) {
                            final addr = s.address;
                            if (addr == null) {
                              showFloatingSnackBar(context,
                                  message: 'No address available',
                                  type: SnackBarType.error);
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReceiveScreen(
                                  address: addr,
                                  xlmBalance: s.xlm,
                                  usdcBalance: s.usdc,
                                  initialToken: token,
                                ),
                              ),
                            );
                          },
                          hasUsdcTrustline:
                          stellar.hasUsdcTrustline(s.address ?? ''),
                        ),
                      ),
                      TabKeepAlive(
                        storageKey: 'recipientsTab',
                        child: RecipientListWidget(colors: colors,xlmBalance: s.xlm,usdcBalance: s.usdc,),
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

  // ───────── actions ─────────
  void _onSend() {
    final s = context.read<WalletHomeVM>().state;
    final addr = s.address;
    if (addr == null) {
      showFloatingSnackBar(context,
          message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    showTokenSelector(
      context,
      addr,
      s.xlm,
      s.usdc,
      title: 'Send Coin',
      screenBuilder: (address, token, balance) =>
          SendScreen(address: address, token: token, balance: balance),
    ).then((_) => context.read<WalletHomeVM>().refresh(force: true));
  }

  void _onReceive() {
    final s = context.read<WalletHomeVM>().state;
    final addr = s.address;
    if (addr == null) {
      showFloatingSnackBar(context,
          message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveScreen(
          address: addr,
          xlmBalance: s.xlm,
          usdcBalance: s.usdc,
          initialToken: 'XLM',
        ),
      ),
    );
  }

  // ───────── VM → View event handling ─────────
  void _onUiEvent(WalletHomeUiEvent e) {
    if (!mounted) return;

    if (e is BootBalancesLoading) {
      // Block UI until balances are fetched (first boot / wallet switch)
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
      // Flip loader to success + auto-close (format here to avoid VM → CurrencyVM coupling)
      final currency = context.read<CurrencyVM>();
      final currencyFmt =
      NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
      final fxXlm = currency.xlmToFiat(e.xlm);
      final fxUsdc = currency.usdcToFiat(e.usdc);
      final totalFiat =
          (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

      _bootBalancesCtl?.update(
        AppAlertType.success,
        title: 'Balances ready',
        subtitle: 'Total ${currencyFmt.format(totalFiat)}',
      );

      Future.delayed(const Duration(milliseconds: 900), () {
        _bootBalancesCtl?.close();
        _bootBalancesCtl = null;
      });
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
        // Mark as acknowledged in the VM so it disappears in strip/list too
        context.read<WalletHomeVM>().ackHint(e.hash);

        Timer(const Duration(seconds: 5), () {
          if (mounted) ctl.close();
        });
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
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Incoming ${h.amount.toStringAsFixed(6)} ${h.assetCode}',
      subtitle: 'From ${_short(h.from)} • Pending confirmation…',
      primaryText: 'Acknowledge',
      onPrimary: () => context.read<WalletHomeVM>().ackHint(h.id),
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
