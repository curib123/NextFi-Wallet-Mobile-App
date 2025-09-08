// lib/Screen/wallet_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Provider/TabProvider.dart';
import 'package:next_fi/Screen/wallet_screen_settings.dart';
import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'package:next_fi/Screen/swap_screen.dart';
import 'package:next_fi/Components/token_chooser.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/asset_widget.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/recipient_list_widget.dart';
import 'package:next_fi/Screen/receive_screen.dart';
import 'package:next_fi/Screen/send_screen.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Helper/AppColor.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Services/seed_storage.dart';

import 'WalletHomeScreenWidgets/action_button.dart';
import 'WalletHomeScreenWidgets/build_tab_bar.dart';
import 'WalletHomeScreenWidgets/home_fab_and_hints.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});
  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /* ================= Services ================= */
  late final StellarWalletService _stellar = StellarWalletService();

  /* ================= Wallet (Stellar) ================= */
  String? _stellarAccountId; // "G..." public address
  String? _secretSeed;

  /* ================= Balances (XLM/USDC) ================= */
  double _xlmBalance = 0, _usdcBalance = 0;
  bool _hideBalance = false, _loadingBalances = true;

  /* ================= Incoming Hints (light) ================= */
  final _incomingHints = <Map<String, dynamic>>[];
  final _seenTxIds = <String>{};
  static const int _maxHints = 4;

  /* ================= Throttle / Schedules ================= */
  static const Duration _minBalancesGap = Duration(minutes: 10);
  static const Duration _incomingWatchInterval = Duration(seconds: 55);
  DateTime? _lastBalancesAt;
  bool _balancesInFlight = false;

  Timer? _balancesTimer;
  StreamSubscription<OperationResponse>? _incomingSub;
  Timer? _debounceBalanceKick;

  /* ================= Pull-to-refresh ================= */
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  /* ================= Anim ================= */
  late final AnimationController _livePulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  /* ================= Lifecycle ================= */
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => mounted ? context.read<AssetProvider>().startRealtimeUpdates() : null);
    _loadWallet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRealtime();
    _livePulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRealtime();
      if (_isStale(_lastBalancesAt, _minBalancesGap)) {
        unawaited(_fetchBalances(force: true));
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopRealtime();
    }
  }

  /* ================= Helpers ================= */
  static String _txIdOf(Map<String, dynamic> tx) => (tx['hash'] ?? tx['txHash'] ?? '').toString();

  bool _isIncomingToMe(Map<String, dynamic> tx) {
    final my = _stellarAccountId;
    if (my == null || my.isEmpty) return false;
    final to = (tx['to'] ?? '').toString();
    return to == my;
  }

  bool _isStale(DateTime? last, Duration gap) => last == null || DateTime.now().difference(last) >= gap;

  void _safeAddHint(Map<String, dynamic> tx) {
    final id = _txIdOf(tx);
    if (id.isEmpty || _seenTxIds.contains(id)) return;
    _seenTxIds.add(id);
    _incomingHints.insert(0, tx);
    if (_incomingHints.length > _maxHints) {
      final removed = _incomingHints.removeLast();
      _seenTxIds.remove(_txIdOf(removed));
    }
  }

  void _scheduleBalanceKick({Duration delay = const Duration(milliseconds: 600)}) {
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = Timer(delay, () => unawaited(_fetchBalances(force: true)));
  }

  /* ================= Data ================= */
  Future<void> _loadWallet() async {
    final mnemonic = await SeedStorage.getSeed(); // active wallet seed
    if (!mounted || mnemonic == null || mnemonic.isEmpty) {
      // New user: no wallet yet → show 0 total instead of endless loader
      if (mounted) {
        setState(() {
          _xlmBalance = 0;
          _usdcBalance = 0;
          _loadingBalances = false;
          _lastBalancesAt = DateTime.now();
        });
      }
      return;
    }

    try {
      final wallet = await StellarWalletService.walletFromMnemonic(mnemonic);
      final kp = await StellarWalletService.getKeyPair(wallet, index: 0);

      setState(() {
        _stellarAccountId = kp.accountId;
        _secretSeed = kp.secretSeed;
      });

      await _fetchBalances(force: true);
      _startRealtime();
    } catch (_) {
      if (!mounted) return;
      // On any error, still fall back to zeros so the UI is stable
      setState(() {
        _xlmBalance = 0;
        _usdcBalance = 0;
        _loadingBalances = false;
        _lastBalancesAt = DateTime.now();
      });
      showFloatingSnackBar(
        context,
        message: 'Failed to load Stellar wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _fetchBalances({bool force = false}) async {
    if (_stellarAccountId == null) {
      // No account yet — treat as 0 balances
      if (mounted && _loadingBalances) {
        setState(() {
          _xlmBalance = 0;
          _usdcBalance = 0;
          _loadingBalances = false;
          _lastBalancesAt = DateTime.now();
        });
      }
      return;
    }
    if (_balancesInFlight) return;
    if (!force && !_isStale(_lastBalancesAt, _minBalancesGap)) return;

    _balancesInFlight = true;
    try {
      final results = await Future.wait<double>([
        _stellar.getXlmBalance(_stellarAccountId!).catchError((_) => 0.0),
        _stellar.getUsdcBalance(_stellarAccountId!).catchError((_) => 0.0),
      ], eagerError: false);

      if (!mounted) return;
      setState(() {
        _xlmBalance = results[0];
        _usdcBalance = results[1];
        _loadingBalances = false;
        _lastBalancesAt = DateTime.now();
      });
    } catch (_) {
      // Any unexpected error → show zeros so Total still renders
      if (!mounted) return;
      setState(() {
        _xlmBalance = 0;
        _usdcBalance = 0;
        _loadingBalances = false;
        _lastBalancesAt = DateTime.now();
      });
    } finally {
      _balancesInFlight = false;
    }
  }

  /* ================= Pull-to-refresh action ================= */
  Future<void> _onRefresh() async {
    // Force a live refresh of balances; hints will update via stream automatically.
    await _fetchBalances(force: true);

    // Defensive: if stream hiccups, kick a delayed fetch.
    _scheduleBalanceKick(delay: const Duration(milliseconds: 400));
  }

  /* ================= Realtime ================= */
  void _startRealtime() {
    _stopRealtime();

    // Periodic gentle refresh (if user leaves app open for long time)
    _balancesTimer = Timer.periodic(_minBalancesGap, (_) => unawaited(_fetchBalances()));

    if (_stellarAccountId != null && _stellarAccountId!.isNotEmpty) {
      try {
        _incomingSub = _stellar.sdk.payments
            .forAccount(_stellarAccountId!)
            .cursor("now")
            .stream()
            .listen((op) {
          if (!mounted) return;

          if (op is PaymentOperationResponse && op.transactionSuccessful == true) {
            final to = op.to;
            if (to == _stellarAccountId) {
              final map = <String, dynamic>{
                'hash': op.transactionHash ?? '',
                'from': op.from,
                'to': to,
                'amount': op.amount,
                'assetCode': op.assetCode ?? (op.assetType == Asset.TYPE_NATIVE ? 'XLM' : null),
                'assetType': op.assetType,
              };
              setState(() => _safeAddHint(map));
              _scheduleBalanceKick();
            }
          }
        }, onError: (_) {
          // Silent; periodic timer + manual refresh cover outages.
        });
      } catch (_) {
        // Swallow; user can still pull-to-refresh.
      }
    }
  }

  void _stopRealtime() {
    _balancesTimer?.cancel();
    _balancesTimer = null;
    _incomingSub?.cancel();
    _incomingSub = null;
    _debounceBalanceKick?.cancel();
    _debounceBalanceKick = null;
  }

  /* ================= UI ================= */
  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = context.watch<CurrencyProvider>();
    final assetProv = context.watch<AssetProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Pull-to-refresh wrapper ─────────────────────────────────────
              RefreshIndicator.adaptive(
                key: _refreshKey,
                onRefresh: _onRefresh,
                edgeOffset: 8,
                displacement: 48,
                // Listen to scroll notifications from nested scrollables (e.g., inside tabs)
                notificationPredicate: (notification) => true,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Top bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _TopBar(colors: colors),
                      ),
                    ),
                    // Header: total balance, actions, incoming strip
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _HeaderSection(
                          colors: colors,
                          currency: currency,
                          hideBalance: _hideBalance,
                          onToggleHide: () => setState(() => _hideBalance = !_hideBalance),
                          loadingBalances: _loadingBalances,
                          stellarAddress: _stellarAccountId,
                          xlmBalance: _xlmBalance,
                          usdcBalance: _usdcBalance,
                          incomingStrip: (_stellarAccountId != null)
                              ? IncomingHintsStrip(
                            colors: colors,
                            stellarAddress: _stellarAccountId!,
                            incomingHints: _incomingHints,
                            onAcknowledge: (tx) {
                              final id = _txIdOf(tx);
                              setState(() {
                                _incomingHints.removeWhere((e) => _txIdOf(e) == id);
                                _seenTxIds.remove(id);
                              });
                            },
                          )
                              : const SizedBox.shrink(),
                          onSend: _onSend,
                          onReceive: _onReceive,
                          isUpdatingBalances: _balancesInFlight,
                          lastBalancesAt: _lastBalancesAt,
                          livePulse: _livePulse,
                        ),
                      ),
                    ),
                    // Tab bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: buildTabBar(colors),
                      ),
                    ),
                    // Tabs body (fills remaining; still scrolls for pull-to-refresh)
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: TabBarView(
                        children: [
                          _TabKeepAlive(
                            storageKey: 'assetsTab',
                            child: AssetWidget(
                              colors: colors,
                              assets: assetProv.assets,
                              logos: assetProv.logos,
                              xlmBalance: _xlmBalance,
                              usdcBalance: _usdcBalance,
                              address: _stellarAccountId ?? '',
                              loading: assetProv.loading || currency.loading || _loadingBalances,
                              onItemTap: (token) {
                                final addr = _stellarAccountId;
                                if (addr == null) {
                                  showFloatingSnackBar(context,
                                      message: "No address available", type: SnackBarType.error);
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReceiveScreen(
                                      address: addr,
                                      xlmBalance: _xlmBalance,
                                      usdcBalance: _usdcBalance,
                                      initialToken: token, // 'XLM' or 'USDC'
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _TabKeepAlive(
                            storageKey: 'recipientsTab',
                            child: RecipientListWidget(
                              colors: colors,
                              fromAddress: _stellarAccountId,
                              xlmBalance: _xlmBalance,
                              usdcBalance: _usdcBalance,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Actions / Hints
              HomeFab(
                colors: colors,
                incomingHints: _incomingHints,
                stellarAddress: _stellarAccountId ?? '',
                xlmBalance: _xlmBalance,
                usdcBalance: _usdcBalance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ================= Actions ================= */
  void _onSend() {
    final addr = _stellarAccountId;
    if (addr == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    showTokenSelector(
      context,
      addr,
      _xlmBalance,
      _usdcBalance,
      title: 'Send Token',
      screenBuilder: (address, token, balance) =>
          SendScreen(address: address, token: token, balance: balance),
    ).then((_) {
      _scheduleBalanceKick(delay: const Duration(milliseconds: 200));
    });
  }

  void _onReceive() {
    final addr = _stellarAccountId;
    if (addr == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveScreen(
          address: addr,
          xlmBalance: _xlmBalance,
          usdcBalance: _usdcBalance,
          initialToken: 'XLM',
        ),
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.colors,
    this.walletName, // optional initial/fallback label
  });

  final AppColor colors;
  final String? walletName;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> with WidgetsBindingObserver {
  static const String _defaultWalletName = "My Wallet";
  String _name = _defaultWalletName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _name = (widget.walletName?.trim().isNotEmpty ?? false)
        ? widget.walletName!.trim()
        : _defaultWalletName;

    _loadName();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh when returning from background (e.g., after renaming/switching/import)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadName();
    }
  }

  Future<void> _loadName() async {
    final meta = await SeedStorage.getActiveWalletMeta();
    if (!mounted) return;
    final fallback = _defaultWalletName;
    final next = (meta?.name.trim().isNotEmpty ?? false) ? meta!.name.trim() : fallback;
    if (next != _name) {
      setState(() => _name = next);
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<TabProvider>(
    builder: (context, tabs, _) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(LucideIcons.package, color: widget.colors.textPrimary, size: 26),
            onPressed: () {
              tabs.setTab(1);
            },
            tooltip: 'Activity',
          ),
          // Center title → opens wallet settings on tap
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WalletScreenSettings(),
                ),
              ).then((_) {
                // After returning from settings, refresh the name
                _loadName();
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 18, color: widget.colors.textPrimary),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: widget.colors.textPrimary, size: 26),
            onPressed: () {
              tabs.setTab(3);
            },
            tooltip: 'Settings',
          ),
        ],
      );
    },
  );
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.colors,
    required this.currency,
    required this.hideBalance,
    required this.onToggleHide,
    required this.loadingBalances,
    required this.stellarAddress,
    required this.xlmBalance,
    required this.usdcBalance,
    required this.incomingStrip,
    required this.onSend,
    required this.onReceive,
    required this.isUpdatingBalances,
    required this.lastBalancesAt,
    required this.livePulse,
  });

  final AppColor colors;
  final CurrencyProvider currency;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final bool loadingBalances;
  final String? stellarAddress;
  final double xlmBalance, usdcBalance;
  final Widget incomingStrip;
  final VoidCallback onSend, onReceive;
  final bool isUpdatingBalances;
  final DateTime? lastBalancesAt;
  final AnimationController livePulse;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());

    final fxXlm = currency.xlmToFiat(xlmBalance);
    final fxUsdc = currency.usdcToFiat(usdcBalance);
    final totalFiat = (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Total Balance',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onToggleHide,
                        child: Icon(hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: colors.textSecondary, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (loadingBalances)
                    const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    _AnimatedFiat(
                      value: hideBalance ? null : totalFiat,
                      currencyFmt: currencyFmt,
                      textColor: colors.textPrimary,
                    ),
                  const SizedBox(height: 4),
                  _UpdatedAgoLabel(last: lastBalancesAt, colors: colors),
                ],
              ),
              // right
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  elevation: 3,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SwapScreen(),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(LucideIcons.shuffle, size: 22, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Swap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            actionButton(colors, Icons.send, 'Send', gradient: true, onTap: onSend),
            actionButton(colors, Icons.call_received, 'Receive', gradient: true, onTap: onReceive),
            actionButton(colors, LucideIcons.wallet, 'Deposit', gradient: true, onTap: () => debugPrint('Deposit')),
            actionButton(colors, Icons.arrow_upward, 'Withdraw',
                gradient: true, onTap: () => debugPrint('Withdraw')),
          ],
        ),
        const SizedBox(height: 20),
        incomingStrip,
      ],
    );
  }
}

class _AnimatedFiat extends StatelessWidget {
  const _AnimatedFiat({required this.value, required this.currencyFmt, required this.textColor});
  final double? value;
  final NumberFormat currencyFmt;
  final Color textColor;

  @override
  Widget build(BuildContext context) => value == null
      ? Text('••••', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: textColor))
      : AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
    child: Text(
      currencyFmt.format(value),
      key: ValueKey(value),
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: textColor),
    ),
  );
}

class _UpdatedAgoLabel extends StatefulWidget {
  const _UpdatedAgoLabel({required this.last, required this.colors});
  final DateTime? last;
  final AppColor colors;

  @override
  State<_UpdatedAgoLabel> createState() => _UpdatedAgoLabelState();
}

class _UpdatedAgoLabelState extends State<_UpdatedAgoLabel> {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.last == null) return const SizedBox.shrink();
    final s = DateTime.now().difference(widget.last!).inSeconds;
    return Text(
      s <= 1 ? 'Updated just now' : 'Updated ${s}s ago',
      style: TextStyle(fontSize: 11, color: widget.colors.textSecondary),
    );
  }
}

class _TabKeepAlive extends StatefulWidget {
  const _TabKeepAlive({super.key, required this.child, required this.storageKey});
  final Widget child;
  final String storageKey;

  @override
  State<_TabKeepAlive> createState() => _TabKeepAliveState();
}

class _TabKeepAliveState extends State<_TabKeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeyedSubtree(key: PageStorageKey(widget.storageKey), child: widget.child);
  }
}

// ignore: unused_element
void unawaited(Future<void> f) {}
