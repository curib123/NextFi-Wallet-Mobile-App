import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/services/offers/models/offers_dtos.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer.dart';
import 'package:next_fi/core/widgets/modal/token_chooser.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/auth/presentation/screens/login_screen.dart';
import 'package:next_fi/features/offers/presentation/screens/market_offers_screen.dart';
import 'package:next_fi/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:next_fi/features/receive/presentation/screens/receive_screen.dart';
import 'package:next_fi/features/send/presentation/screens/send_screen.dart';
import 'package:next_fi/features/swap/presentation/screens/swap_screen.dart';
import 'package:next_fi/features/trades/presentation/screens/trade_history_screen.dart';
import 'package:next_fi/features/trades/presentation/viewmodels/trade_inbox_summary_provider.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/verification_flow_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_state.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/asset_widget.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/header_section.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/incoming_hints_strip.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/top_bar.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/wallet_header_guide.dart';

class WalletHomeScreen extends ConsumerStatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  ConsumerState<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends ConsumerState<WalletHomeScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  late final AnimationController _livePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  final Map<String, AppAlertController> _hintAlertCtrls =
      <String, AppAlertController>{};
  StreamSubscription<WalletHomeUiEvent>? _uiSub;
  VoidCallback? _walletVmListener;
  String? _lastTxBoundAddress;
  String? _lastPortfolioBoundAddress;
  WalletSnapshotTrigger _pendingPortfolioTrigger =
      WalletSnapshotTrigger.appOpen;
  bool _animateTotal = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = ref.read(walletHomeVmProvider);
      final txVm = ref.read(transactionsVmProvider);
      final portfolioVm = ref.read(portfolioVmProvider);

      _uiSub = vm.uiEvents.listen(_onUiEvent);
      vm.attachConfirmedTxStream(txVm.incomingStream);
      _walletVmListener = () {
        final addr = vm.state.address;
        if (addr != _lastTxBoundAddress) {
          _lastTxBoundAddress = addr;
          txVm.bindToAddress(addr);
        }
        if (addr != _lastPortfolioBoundAddress) {
          final previous = _lastPortfolioBoundAddress;
          _lastPortfolioBoundAddress = addr;
          _pendingPortfolioTrigger = previous == null
              ? WalletSnapshotTrigger.appOpen
              : WalletSnapshotTrigger.walletSwitch;
          unawaited(
            portfolioVm.bindActiveWallet(
              localWalletId: ref.read(seedKeypairProvider).activeWalletId,
              address: addr,
              label: vm.state.walletName,
            ),
          );
        }
      };
      vm.addListener(_walletVmListener!);

      unawaited(() async {
        await vm.boot();
        if (!mounted) return;
        _walletVmListener?.call();
      }());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePulse.dispose();
    _uiSub?.cancel();
    _uiSub = null;

    final vm = ref.read(walletHomeVmProvider);
    if (_walletVmListener != null) {
      vm.removeListener(_walletVmListener!);
      _walletVmListener = null;
    }

    for (final ctl in _hintAlertCtrls.values) {
      ctl.close();
    }
    _hintAlertCtrls.clear();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vm = ref.read(walletHomeVmProvider);
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
    final vm = ref.watch(walletHomeVmProvider);
    final s = vm.state;
    final currency = ref.watch(currencyVmProvider);
    final assetsVm = ref.watch(assetVmProvider);
    final tradeInboxSummary = ref.watch(tradeInboxSummaryProvider);
    final appShell = ref.watch(appShellProvider);

    final allAssetList = assetsVm.assets;
    final walletHomeAssetList = assetsVm.walletHomeAssets;
    final showAssetTileSkeleton =
        !assetsVm.hasCatalogData &&
        walletHomeAssetList.isEmpty &&
        !s.hasHydratedBalances &&
        (allAssetList.isEmpty || s.loadingBalances);
    final showHeaderLoader = s.loadingBalances && !s.hasHydratedBalances;
    final currencyFmt = NumberFormat.simpleCurrency(
      name: currency.fiat.toUpperCase(),
    );
    final totalFiat = _portfolioFiatTotal(
      currency: currency,
      assets: allAssetList,
      balancesByAssetId: s.balancesByAssetId,
    );
    final chartSeries = _xlmPriceWindowSeries(currency, s.selectedWindow);
    final chartDeltaFiat = _seriesDelta(chartSeries);
    final activeTradeCount = appShell.isAuthenticated
        ? tradeInboxSummary.maybeWhen(
            data: (summary) => summary.activeTradeCount,
            orElse: () => 0,
          )
        : 0;
    final logosById = <String, String>{
      for (final a in allAssetList)
        a.id: (a.primaryLogo.isNotEmpty
            ? a.primaryLogo
            : assetsVm.logoFor(a.symbol)),
    };

    return Scaffold(
      backgroundColor: colors.surface,
      drawer: const AppDrawer(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'wallet-home-theme-fab',
            onPressed: () =>
                ref.read(settingsVmProvider).showAppearanceSheet(context),
            backgroundColor: colors.surface,
            foregroundColor: colors.textPrimary,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.border),
            ),
            child: const Icon(LucideIcons.palette, size: 18),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'wallet-home-recipient-fab',
            onPressed: _openRecipientList,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(LucideIcons.users, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _handleRefresh,
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
                    loadingBalances: showHeaderLoader,
                    totalFiat: totalFiat,
                    lastBalancesAt: s.lastBalancesAt,
                    onPortfolio: _openPortfolio,
                    onSwap: _openHeaderScanner,
                    onSend: () => vm.onSendPressed(),
                    onReceive: () => vm.onReceivePressed(),
                    onP2P: _openP2PMarketplace,
                    livePulse: _livePulse,
                    incomingStrip: s.hasWallet
                        ? IncomingHintsStrip(
                            colors: colors,
                            stellarAddress: s.address ?? '',
                            incomingHints: s.hints
                                .map(
                                  (h) => {
                                    'hash': h.id,
                                    'from': h.from,
                                    'to': h.to,
                                    'amount': h.amount.toStringAsFixed(6),
                                    'assetCode': h.assetCode,
                                  },
                                )
                                .toList(),
                            onAcknowledge: (tx) => ref
                                .read(walletHomeVmProvider)
                                .ackHint((tx['hash'] ?? '').toString()),
                            onActiveTradeTap: _openManageTrades,
                            activeTradeCount: activeTradeCount,
                            walletState: s,
                          )
                        : const SizedBox.shrink(),
                    animateTotal: _animateTotal,
                    selectedWindow: s.selectedWindow,
                    onWindowChanged: vm.setPriceWindow,
                    reserveXlm: s.xlmTotalReserve,
                    chartSeries: chartSeries,
                    chartDeltaFiat: chartDeltaFiat,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: WalletHeaderGuide(
                    colors: colors,
                    xlmBalance: s.xlm,
                    usdcBalance: s.usdc,
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: AssetWidget(
                  colors: colors,
                  assets: walletHomeAssetList,
                  logos: logosById,
                  balancesByAssetId: s.balancesByAssetId,
                  address: s.address ?? '',
                  loading: showAssetTileSkeleton,
                  onItemTap: (token) {
                    vm.onReceivePressed(initialToken: token);
                  },
                  hasUsdcTrustline: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    await walletVm.refresh(force: true);
    await portfolioVm.refreshForWallet(
      walletState: walletVm.state,
      trigger: WalletSnapshotTrigger.manualRefresh,
    );
  }

  List<double> _xlmPriceWindowSeries(CurrencyVM currency, PriceWindow window) {
    final xlmSeries = switch (window) {
      PriceWindow.h24 => currency.xlmHistory24h,
      PriceWindow.d7 => currency.xlmHistory7,
      PriceWindow.d30 => currency.xlmHistory30,
      PriceWindow.y1 => currency.xlmHistory365,
    };
    if (xlmSeries.where((value) => value.isFinite).length < 2) {
      return const <double>[];
    }

    return xlmSeries.where((value) => value.isFinite).toList(growable: false);
  }

  double _seriesDelta(List<double> series) {
    if (series.length < 2) return 0.0;
    final first = series.first.isFinite ? series.first : 0.0;
    final last = series.last.isFinite ? series.last : 0.0;
    return last - first;
  }

  double _portfolioFiatTotal({
    required CurrencyVM currency,
    required List<AssetModel> assets,
    required Map<String, double> balancesByAssetId,
  }) {
    var total = 0.0;
    for (final asset in assets) {
      final balance = balancesByAssetId[asset.id] ?? 0.0;
      if (balance <= 0) continue;
      total += currency.assetAmountToFiat(asset, balance);
    }
    return total.isFinite ? total : 0.0;
  }

  Future<void> _openRecipientList() async {
    if (!mounted) return;
    final colors = AppColor.of(context);
    final s = ref.read(walletHomeVmProvider).state;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipientListWidget(
          colors: colors,
          fromAddress: s.address,
          xlmBalance: s.xlm,
          usdcBalance: s.usdc,
          showAppBar: true,
        ),
      ),
    );
  }

  Future<void> _autoSaveActiveWalletAddressIfMissing() async {
    if (!mounted) return;
    try {
      await ref.read(walletHomeVmProvider).ensureActiveWalletSavedIfMissing();
    } catch (_) {}
  }

  Future<void> _openPortfolio() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PortfolioScreen()));
  }

  Future<void> _openHeaderScanner() async {
    final vm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    final state = vm.state;
    final address = (state.address ?? '').trim();
    if (address.isEmpty) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Wallet not ready',
        type: SnackBarType.warning,
      );
      return;
    }

    try {
      await showTokenSelector(
        context,
        address,
        balanceResolver: (asset) => state.balancesByAssetId[asset.id] ?? 0.0,
        title: 'Select Asset',
        screenBuilder: (addr, token, balance) => SendScreen(
          address: addr,
          assetId: token,
          balance: balance,
          autoOpenScanner: true,
          onTransactionCompleted: () async {
            await vm.refresh(force: true);
            await portfolioVm.refreshForWallet(
              walletState: vm.state,
              trigger: WalletSnapshotTrigger.send,
            );
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => SendScreen(
            address: address,
            assetId: 'stellar',
            balance: state.xlm,
            autoOpenScanner: true,
            onTransactionCompleted: () async {
              await vm.refresh(force: true);
              await portfolioVm.refreshForWallet(
                walletState: vm.state,
                trigger: WalletSnapshotTrigger.send,
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        await vm.refresh(force: true);
      }
    }
  }

  Future<void> _openSwap() async {
    if (!mounted) return;
    final walletVm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);
    final swapVm = ref.read(swapVmProvider);
    final beforeTx = swapVm.lastSuccessfulSwapTxId;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SwapScreen()),
    );
    if (!mounted) return;
    await walletVm.refresh(force: true);
    if (swapVm.lastSuccessfulSwapTxId != null &&
        swapVm.lastSuccessfulSwapTxId != beforeTx) {
      await portfolioVm.refreshForWallet(
        walletState: walletVm.state,
        trigger: WalletSnapshotTrigger.swap,
      );
    }
  }

  Future<void> _openManageTrades() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TradeHistoryScreen()));
  }

  Future<void> _openP2PMarketplace() async {
    final allowed = await _ensureVerifiedForTradeAccess();
    if (!allowed || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MarketOffersScreen(initialType: OfferType.sell),
      ),
    );
  }

  Future<bool> _ensureVerifiedForTradeAccess() async {
    try {
      final allowed = await ref.read(walletHomeVmProvider).hasTradeAccess();
      if (allowed) return true;
    } catch (_) {}

    if (!mounted) return false;
    showFloatingSnackBar(
      context,
      message: 'Verification READY is required for trades',
      type: SnackBarType.warning,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerificationFlowScreen()),
    );
    return false;
  }

  void _onUiEvent(WalletHomeUiEvent e) async {
    if (!mounted) return;

    SnackBarType mapSeverity(UiSeverity s) {
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

    final vm = ref.read(walletHomeVmProvider);
    final portfolioVm = ref.read(portfolioVmProvider);

    if (e is NavigateToLogin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (e is StartBuyFlow) {
      final allowed = await _ensureVerifiedForTradeAccess();
      if (!allowed || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SnackBar(content: Text('Buy'))),
      );
      return;
    }

    if (e is StartSellFlow) {
      final allowed = await _ensureVerifiedForTradeAccess();
      if (!allowed || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SnackBar(content: Text('Sell'))),
      );
      return;
    }

    if (e is ShowToastEvent) {
      showFloatingSnackBar(
        context,
        message: e.message,
        type: mapSeverity(e.severity),
      );
      return;
    }

    if (e is BootBalancesLoading) {
      setState(() => _animateTotal = false);
      return;
    }

    if (e is BootBalancesReady) {
      setState(() => _animateTotal = true);
      unawaited(_autoSaveActiveWalletAddressIfMissing());
      await portfolioVm.refreshForWallet(
        walletState: vm.state,
        trigger: _pendingPortfolioTrigger,
      );
      return;
    }

    if (e is StartSendFlow) {
      await showTokenSelector(
        context,
        e.address,
        balanceResolver: (asset) => vm.state.balancesByAssetId[asset.id] ?? 0.0,
        title: 'Select Asset',
        screenBuilder: (address, token, balance) => SendScreen(
          address: address,
          assetId: token,
          balance: balance,
          onTransactionCompleted: () async {
            await vm.refresh(force: true);
            await portfolioVm.refreshForWallet(
              walletState: vm.state,
              trigger: WalletSnapshotTrigger.send,
            );
          },
        ),
      );

      if (!mounted) return;
      await vm.refresh(force: true);
      return;
    }

    if (e is StartReceiveFlow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiveScreen(
            address: e.address,
            initialAssetId: e.initialToken ?? 'stellar',
          ),
        ),
      );
      return;
    }

    if (e is NavigateToSwap) {
      await _openSwap();
      return;
    }

    if (e is IncomingHintAddedEvent) {
      _showPendingAlertForHint(e.hint);
      return;
    }

    if (e is TransactionConfirmedEvent) {
      final ctl = _hintAlertCtrls.remove(e.hash);
      await vm.refresh(force: true);
      await portfolioVm.refreshForWallet(
        walletState: vm.state,
        trigger: WalletSnapshotTrigger.receiveDetected,
      );

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
    }
  }

  void _showPendingAlertForHint(dynamic h) {
    if (!mounted) return;
    final vm = ref.read(walletHomeVmProvider);
    final ctl = showAppAlert(
      context,
      type: AppAlertType.loading,
      title: 'Incoming ${h.amount.toStringAsFixed(6)} ${h.assetCode}',
      subtitle: 'From ${_short(h.from)} - Pending confirmation...',
      primaryText: 'Acknowledge',
      onPrimary: () => vm.ackHint(h.id),
      barrierDismissible: true,
    );
    _hintAlertCtrls[h.id.toString()] = ctl;
  }

  String _short(String addr) {
    if (addr.isEmpty) return '-';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }
}
