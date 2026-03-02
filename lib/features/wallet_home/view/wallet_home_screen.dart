import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:next_fi/common/components/drawer/appdrawer.dart';
import 'package:next_fi/common/components/modal/chat_consent_modal.dart';
import 'package:next_fi/features/auth/view/login.dart';
import 'package:next_fi/features/chat/view/chat_hub_screen.dart';
import 'package:next_fi/features/chat/view/chat_thread_screen.dart';
import 'package:next_fi/features/offers/view/market_offers_screen.dart';
import 'package:next_fi/features/wallet_home/view/widgets/asset_widget.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/features/receive/view/receive_screen.dart';
import 'package:next_fi/features/send/view/send_screen.dart';
import 'package:next_fi/features/swap/view/swap_screen.dart';
import 'package:next_fi/features/transactions/view_model/transactions_vm.dart';
import 'package:next_fi/features/verification_flow/view/verification_flow_screen.dart';
import 'package:next_fi/features/wallet_home/view/widgets/build_tab_bar.dart';
import 'package:next_fi/features/wallet_home/view/widgets/header_section.dart';
import 'package:next_fi/features/wallet_home/view/widgets/incoming_hints_strip.dart';
import 'package:next_fi/features/wallet_home/view/widgets/recipient_list_widget.dart';
import 'package:next_fi/features/wallet_home/view/widgets/tab_keep_alive.dart';
import 'package:next_fi/features/wallet_home/view/widgets/top_bar.dart';
import 'package:next_fi/features/wallet_home/view_model/wallet_home_vm.dart';

import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/common/components/modal/token_chooser.dart';
import 'package:next_fi/common/components/alert/AppAlert.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/services/chat/chat_core_service.dart';
import 'package:next_fi/services/chat/models/chat_dtos.dart';
import 'package:next_fi/services/chat/models/chat_models.dart';
import 'package:next_fi/services/oath2.0/auth_service.dart';
import 'package:next_fi/services/secure_storage/security_storage.dart';
import 'package:next_fi/services/verification/models/verification_models.dart';
import 'package:next_fi/services/verification/verification_core_service.dart';
import 'package:next_fi/services/offers/models/offers_dtos.dart';
import 'package:next_fi/services/wallet/wallet_manager.dart';
import 'package:next_fi/reusable_view_model/asset_vm.dart';
import 'package:next_fi/reusable_view_model/currency_vm.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});
  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _ChatFloatingButton extends StatelessWidget {
  const _ChatFloatingButton({
    required this.colors,
    required this.unreadCount,
    required this.onTap,
  });

  final AppColor colors;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'wallet_home_chat_fab',
          onPressed: onTap,
          tooltip: 'Messenger',
          elevation: 0,
          backgroundColor: colors.primary,
          foregroundColor: AppColor.of(context).onPrimary,
          child: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColor.of(context).onPrimary,
                  width: 1.6,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                style: TextStyle(
                  color: AppColor.of(context).onPrimary,
                  fontSize: 10.3,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  static const String _kChatConsentKey = 'chat.user_consent.v1';
  static const String _kChatConsentAtKey = 'chat.user_consent_at.v1';

  final _auth = AuthService();
  final _chat = ChatCoreService.I;

  late final AnimationController _livePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  final Map<String, AppAlertController> _hintAlertCtrls =
      <String, AppAlertController>{};
  AppAlertController? _bootBalancesCtl;
  StreamSubscription<WalletHomeUiEvent>? _uiSub;
  Timer? _chatRefreshTimer;
  int _unreadChatCount = 0;
  String? _walletAutoSavedAddress;

  // First open: no counting animation; enabled only after the FIRST ready has passed.
  bool _animateTotal = false;
  bool _shownInitialTotal = false;

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
      unawaited(_refreshUnreadChatCount());
    });

    _chatRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_refreshUnreadChatCount());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePulse.dispose();

    _uiSub?.cancel();
    _uiSub = null;
    _chatRefreshTimer?.cancel();
    _chatRefreshTimer = null;

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
      unawaited(_refreshUnreadChatCount());
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
    final assetsVM = context.watch<AssetVM>();

    final currencyFmt = NumberFormat.simpleCurrency(
      name: currency.fiat.toUpperCase(),
    );
    final fxXlm = currency.xlmToFiat(s.xlm);
    final fxUsdc = currency.usdcToFiat(s.usdc);
    final totalFiat =
        (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

    final assetList = assetsVM.assets;
    final logosById = {
      for (final a in assetList)
        a.id: (a.primaryLogo.isNotEmpty
            ? a.primaryLogo
            : assetsVM.logoFor(a.symbol)),
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,

        /// DRAWER HERE
        drawer: const AppDrawer(),
        floatingActionButton: _ChatFloatingButton(
          colors: colors,
          unreadCount: _unreadChatCount,
          onTap: _openFloatingChat,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

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
                              onAcknowledge: (tx) => context
                                  .read<WalletHomeVM>()
                                  .ackHint((tx['hash'] ?? '').toString()),
                              walletState: s,
                            )
                          : const SizedBox.shrink(),
                      animateTotal: _animateTotal,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
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
                          loading:
                              assetsVM.loading ||
                              currency.loading ||
                              s.loadingBalances,
                          onItemTap: (token) {
                            vm.onReceivePressed(initialToken: token);
                          },
                          hasUsdcTrustline: null,
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

  // ──────────────────────── Event handling (UI side effects) ────────────────────────
  Future<void> _refreshUnreadChatCount() async {
    try {
      final authenticated = await _auth.isAuthenticated;
      if (!authenticated) {
        if (!mounted) return;
        if (_unreadChatCount != 0) {
          setState(() => _unreadChatCount = 0);
        }
        return;
      }

      const query = ChatListQuery(page: 1, limit: 50);
      final data = await Future.wait([
        _chat.listThreads(query),
        _chat.listFriends(query),
      ]);

      final threads = (data[0] as ChatPaged<ChatDirectThreadModel>).items;
      final friends = (data[1] as ChatPaged<ChatFriendModel>).items;

      final threadUnreadByFriend = <String, int>{};
      for (final thread in threads) {
        final key = thread.friendUserId.trim();
        if (key.isEmpty) continue;
        final current = threadUnreadByFriend[key] ?? 0;
        threadUnreadByFriend[key] = current + thread.unreadCount;
      }

      var unread = 0;
      for (final friend in friends) {
        final key = friend.friendUserId.trim();
        final threadUnread = key.isEmpty
            ? 0
            : (threadUnreadByFriend.remove(key) ?? 0);
        final friendUnread = friend.newUnreadMessageCount;
        unread += threadUnread > friendUnread ? threadUnread : friendUnread;
      }

      unread += threadUnreadByFriend.values.fold<int>(0, (sum, v) => sum + v);
      if (!mounted) return;
      if (unread != _unreadChatCount) {
        setState(() => _unreadChatCount = unread);
      }
    } catch (_) {
      if (!mounted) return;
      if (_unreadChatCount != 0) {
        setState(() => _unreadChatCount = 0);
      }
    }
  }

  Future<bool> _ensureChatConsent() async {
    try {
      final stored = await SecurityStorage.read(_kChatConsentKey);
      if (stored == 'accepted') return true;
    } catch (_) {
      // Ask consent now when read fails.
    }

    if (!mounted) return false;
    final accepted = await showChatConsentModal(context);
    if (!accepted) return false;

    try {
      await SecurityStorage.save(_kChatConsentKey, 'accepted');
      await SecurityStorage.save(
        _kChatConsentAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Allow this session even if persistence fails.
    }
    return true;
  }

  Future<void> _openFloatingChat() async {
    final authenticated = await _auth.isAuthenticated;
    if (!authenticated) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (mounted) {
        await _refreshUnreadChatCount();
      }
      return;
    }

    final verified = await _ensureVerifiedForTradeAccess();
    if (!verified || !mounted) return;

    final consented = await _ensureChatConsent();
    if (!consented || !mounted) return;

    ChatDirectThreadModel? targetThread;
    try {
      final threads = await _chat.listThreads(
        const ChatListQuery(page: 1, limit: 50),
      );
      final unreadThreads =
          threads.items.where((thread) => thread.unreadCount > 0).toList()
            ..sort(
              (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
      if (unreadThreads.isNotEmpty) {
        targetThread = unreadThreads.first;
      }
    } catch (_) {
      // Fallback to chat hub.
    }

    if (!mounted) return;
    if (targetThread != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            thread: targetThread!,
            username: targetThread.friendUser?.username,
            avatarUrl: targetThread.friendUser?.avatarUrl,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatHubScreen()),
      );
    }

    if (mounted) {
      await _refreshUnreadChatCount();
    }
  }

  Future<void> _autoSaveActiveWalletAddressIfMissing() async {
    if (!mounted) return;

    final vm = context.read<WalletHomeVM>();
    final address = (vm.state.address ?? '').trim();
    if (address.isEmpty) return;

    if (_walletAutoSavedAddress == address) return;

    final authenticated = await _auth.isAuthenticated;
    if (!mounted) return;
    if (!authenticated) return;

    bool existsInBackend = false;
    try {
      existsInBackend = await WalletManager.I.hasAddressInBackend(address);
    } catch (_) {
      return;
    }
    if (!mounted) return;

    if (existsInBackend) {
      _walletAutoSavedAddress = address;
      return;
    }

    final label = (vm.state.walletName ?? '').trim();

    try {
      await WalletManager.I.saveAddressIfMissing(
        publicAddress: address,
        label: label.isEmpty ? null : label,
      );
      _walletAutoSavedAddress = address;
    } catch (_) {
      // Silent best-effort; we'll retry on next wallet/home refresh.
    }
  }

  Future<void> _openHeaderScanner() async {
    final vm = context.read<WalletHomeVM>();
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

    final xlmBalance = state.xlm;
    final usdcBalance = state.usdc;

    try {
      await showTokenSelector(
        context,
        address,
        xlmBalance,
        usdcBalance,
        title: 'Select Coin',
        screenBuilder: (addr, token, balance) => SendScreen(
          address: addr,
          token: token,
          balance: balance,
          autoOpenScanner: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => SendScreen(
            address: address,
            token: 'XLM',
            balance: xlmBalance,
            autoOpenScanner: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        await vm.refresh(force: true);
      }
    }
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
      final verification = await VerificationCoreService.I.getMe();
      if (verification.status == TrustStatus.ready) return true;
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

    final vm = context.read<WalletHomeVM>();

    /// ───────────────── LOGIN NAVIGATION ─────────────────
    if (e is NavigateToLogin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    /// ───────────────── BUY FLOW ─────────────────
    if (e is StartBuyFlow) {
      final allowed = await _ensureVerifiedForTradeAccess();
      if (!allowed || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SnackBar(content: Text("Buy"))),
      );
      return;
    }

    /// ───────────────── SELL FLOW ─────────────────
    if (e is StartSellFlow) {
      final allowed = await _ensureVerifiedForTradeAccess();
      if (!allowed || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SnackBar(content: Text("Sell"))),
      );
      return;
    }

    /// ───────────────── TOAST ─────────────────
    if (e is ShowToastEvent) {
      showFloatingSnackBar(
        context,
        message: e.message,
        type: mapSeverity(e.severity),
      );
      return;
    }

    /// ───────────────── BOOT LOADING ─────────────────
    if (e is BootBalancesLoading) {
      setState(() => _animateTotal = false);

      _bootBalancesCtl ??= showAppAlert(
        context,
        type: AppAlertType.loading,
        title: 'Fetching balances',
        subtitle: 'Calculating your total…',
        barrierDismissible: false,
      );
      return;
    }

    /// ───────────────── BOOT READY ─────────────────
    if (e is BootBalancesReady) {
      final currency = context.read<CurrencyVM>();
      final currencyFmt = NumberFormat.simpleCurrency(
        name: currency.fiat.toUpperCase(),
      );

      final totalFiat = currency.xlmToFiat(e.xlm) + currency.usdcToFiat(e.usdc);

      _bootBalancesCtl?.update(
        AppAlertType.success,
        title: 'Balances ready',
        subtitle: 'Total ${currencyFmt.format(totalFiat)}',
      );

      _bootBalancesCtl?.close();
      _bootBalancesCtl = null;

      setState(() {
        _animateTotal = _shownInitialTotal;
        _shownInitialTotal = true;
      });
      unawaited(_autoSaveActiveWalletAddressIfMissing());

      return;
    }

    /// ───────────────── SEND FLOW ─────────────────
    if (e is StartSendFlow) {
      await showTokenSelector(
        context,
        e.address,
        e.xlm,
        e.usdc,
        title: 'Send Token',
        screenBuilder: (address, token, balance) =>
            SendScreen(address: address, token: token, balance: balance),
      );

      if (!mounted) return;
      await vm.refresh(force: true);
      return;
    }

    /// ───────────────── RECEIVE FLOW ─────────────────
    if (e is StartReceiveFlow) {
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

    /// ───────────────── SWAP ─────────────────
    if (e is NavigateToSwap) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SwapScreen()),
      );
      return;
    }

    /// ───────────────── INCOMING HINT ─────────────────
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
    _hintAlertCtrls[h.id.toString()] = ctl;
  }

  String _short(String addr) {
    if (addr.isEmpty) return '—';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }
}
