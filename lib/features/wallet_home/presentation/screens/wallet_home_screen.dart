import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/core/widgets/drawer/app_drawer.dart';
import 'package:next_fi/features/auth/presentation/screens/login_screen.dart';
import 'package:next_fi/features/trades/presentation/screens/trade_history_screen.dart';
import 'package:next_fi/features/verification_flow/presentation/screens/verification_flow_screen.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/features/receive/presentation/screens/receive_screen.dart';
import 'package:next_fi/features/send/presentation/screens/send_screen.dart';
import 'package:next_fi/features/swap/presentation/screens/swap_screen.dart';
import 'package:next_fi/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/incoming_hints_strip.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/top_bar.dart';
import 'package:next_fi/features/wallet_home/presentation/widgets/wallet_header_guide.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';
import 'package:next_fi/app/viewmodels/currency_vm.dart';
import 'package:next_fi/features/trades/presentation/viewmodels/trade_inbox_summary_provider.dart';

import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/core/widgets/alert/app_alert.dart';
import 'package:next_fi/core/widgets/modal/token_chooser.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/app/theme/app_fonts.dart';

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

      _uiSub = vm.uiEvents.listen(_onUiEvent);
      vm.attachConfirmedTxStream(txVm.incomingStream);
      _walletVmListener = () {
        final addr = vm.state.address;
        if (addr != _lastTxBoundAddress) {
          _lastTxBoundAddress = addr;
          txVm.bindToAddress(addr);
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
    final assetsVM = ref.watch(assetVmProvider);
    final tradeInboxSummary = ref.watch(tradeInboxSummaryProvider);
    final appShell = ref.watch(appShellProvider);
    final allAssetList = assetsVM.assets;

    final totalFiat = _portfolioFiatTotal(
      currency: currency,
      assets: allAssetList,
      balancesByAssetId: s.balancesByAssetId,
    );
    final activeTradeCount = appShell.isAuthenticated
        ? tradeInboxSummary.maybeWhen(
            data: (summary) => summary.activeTradeCount,
            orElse: () => 0,
          )
        : 0;
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
            onPressed: () => _openRecipientList(),
            backgroundColor: colors.primary,
            foregroundColor: AppColor.of(context).onPrimary,
            elevation: 8,
            shape: const CircleBorder(),
            child: Icon(LucideIcons.users, size: 20),
          ),
        ],
      ),

      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: () => ref.read(walletHomeVmProvider).manualRefresh(),
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
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                  child: _PortfolioShortcutCard(
                    colors: colors,
                    currency: currency,
                    liveTotalFiat: totalFiat,
                    walletLabel: s.walletName,
                    walletAddress: s.address,
                    onTap: _openPortfolioScreen,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: s.hasWallet
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
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _openPortfolioScreen() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PortfolioScreen()),
    );
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

  Future<void> _openManageTrades() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TradeHistoryScreen()));
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
        MaterialPageRoute(builder: (_) => SnackBar(content: Text("Buy"))),
      );
      return;
    }

    if (e is StartSellFlow) {
      final allowed = await _ensureVerifiedForTradeAccess();
      if (!allowed || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SnackBar(content: Text("Sell"))),
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
      return;
    }

    if (e is BootBalancesReady) {
      unawaited(_autoSaveActiveWalletAddressIfMissing());

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
          onTransactionCompleted: () => vm.onSuccessfulSend(),
        ),
      );

      if (!mounted) return;
      await vm.onSuccessfulSend();
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
      unawaited(vm.refresh(force: true));

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
    if (addr.isEmpty) {
      return '-';
    }
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }
}

class _PortfolioShortcutCard extends StatelessWidget {
  const _PortfolioShortcutCard({
    required this.colors,
    required this.currency,
    required this.liveTotalFiat,
    required this.walletLabel,
    required this.walletAddress,
    required this.onTap,
  });

  final AppColor colors;
  final CurrencyVM currency;
  final double liveTotalFiat;
  final String? walletLabel;
  final String? walletAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface.withValues(alpha: 0.98),
                colors.surfaceRaised.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.lineChart,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio',
                      style: AppFonts.title(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      walletLabel?.trim().isNotEmpty == true
                          ? '${walletLabel!.trim()} • ${_shortAddress(walletAddress)}'
                          : _shortAddress(walletAddress),
                      style: AppFonts.body(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.formatFiat(liveTotalFiat),
                      style: AppFonts.body(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.background.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.arrowRight,
                  color: colors.textPrimary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortAddress(String? address) {
    final value = (address ?? '').trim();
    if (value.isEmpty) return 'Wallet unavailable';
    if (value.length <= 14) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 6)}';
  }
}
