// lib/Screen/wallet_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Screen/price_chart_card.dart';
import 'package:provider/provider.dart';

import 'package:next_fi/Components/SnackBar.dart';
import 'package:next_fi/Components/token_chooser.dart';
import 'package:next_fi/Helper/AppColor.dart';

import 'package:next_fi/Provider/AssetProvider.dart';
import 'package:next_fi/Provider/CurrencyProvider.dart';
import 'package:next_fi/Provider/HomeWalletProvider.dart';
import 'package:next_fi/Provider/TabProvider.dart';

import 'package:next_fi/Screen/WalletHomeScreenWidgets/action_button.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/asset_widget.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/build_tab_bar.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/home_fab_and_hints.dart';
import 'package:next_fi/Screen/WalletHomeScreenWidgets/recipient_list_widget.dart';

import 'package:next_fi/Screen/receive_screen.dart';
import 'package:next_fi/Screen/send_screen.dart';
import 'package:next_fi/Screen/swap_screen.dart';
import 'package:next_fi/Screen/wallet_screen_settings.dart';

import 'package:next_fi/Services/stellar/stellar_wallet_services.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});
  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final WalletHomeProvider _home =
  WalletHomeProvider(stellar: StellarWalletService());

  late final AnimationController _livePulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    context.read<AssetProvider>().startRealtimeUpdates();

    // Fire-and-forget boot
    unawaited(_home.boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePulse.dispose();
    _home.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _home.startRealtime();
      unawaited(_home.refresh());
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _home.stopRealtime();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);

    return ChangeNotifierProvider<WalletHomeProvider>.value(
      value: _home,
      builder: (context, _) {
        final home = context.watch<WalletHomeProvider>();
        final currency = context.watch<CurrencyProvider>();
        final assets = context.watch<AssetProvider>();

        final currencyFmt =
        NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
        final fxXlm = currency.xlmToFiat(home.xlm);
        final fxUsdc = currency.usdcToFiat(home.usdc);
        final totalFiat =
            (fxXlm.isFinite ? fxXlm : 0.0) + (fxUsdc.isFinite ? fxUsdc : 0.0);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: colors.surface,
            body: SafeArea(
              child: RefreshIndicator.adaptive(
                onRefresh: () => _home.refresh(force: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _TopBar(
                          colors: colors,
                          walletName: home.walletName, // shows active wallet name
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20,),
                        child: _HeaderSection(
                          colors: colors,
                          currencyFmt: currencyFmt,
                          loadingBalances: home.loadingBalances,
                          totalFiat: totalFiat,
                          lastBalancesAt: home.lastBalancesAt,
                          onSwap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SwapScreen()),
                          ),
                          onSend: _onSend,
                          onReceive: _onReceive,
                          livePulse: _livePulse,
                          incomingStrip: (home.hasWallet)
                              ? IncomingHintsStrip(
                            colors: colors,
                            stellarAddress: home.address!,
                            incomingHints: home.hints
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
                              _home.ackHint(id);
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
                          _TabKeepAlive(
                            storageKey: 'assetsTab',
                            child: AssetWidget(
                              colors: colors,
                              assets: assets.assets,
                              logos: assets.logos,
                              xlmBalance: home.xlm,
                              usdcBalance: home.usdc,
                              address: home.address ?? '',
                              loading: assets.loading ||
                                  currency.loading ||
                                  home.loadingBalances,
                              onItemTap: (token) {
                                final addr = home.address;
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
                                      xlmBalance: home.xlm,
                                      usdcBalance: home.usdc,
                                      initialToken: token,
                                    ),
                                  ),
                                );
                              },
                              hasUsdcTrustline: StellarWalletService().hasUsdcTrustline(home.address ?? ''),
                            ),
                          ),
                          _TabKeepAlive(
                            storageKey: 'recipientsTab',
                            child: RecipientListWidget(
                              colors: colors,
                              fromAddress: home.address,
                              xlmBalance: home.xlm,
                              usdcBalance: home.usdc,
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
      },
    );
  }

  // ---- Actions ----
  void _onSend() {
    final addr = _home.address;
    if (addr == null) {
      showFloatingSnackBar(context,
          message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    showTokenSelector(
      context,
      addr,
      _home.xlm,
      _home.usdc,
      title: 'Send Token',
      screenBuilder: (address, token, balance) =>
          SendScreen(address: address, token: token, balance: balance),
    ).then((_) => _home.refresh(force: true));
  }

  void _onReceive() {
    final addr = _home.address;
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
          xlmBalance: _home.xlm,
          usdcBalance: _home.usdc,
          initialToken: 'XLM',
        ),
      ),
    );
  }
}

/* -------------------------- rest of your widgets -------------------------- */

class _TopBar extends StatelessWidget {
  const _TopBar({required this.colors, this.walletName});
  final AppColor colors;
  final String? walletName;

  @override
  Widget build(BuildContext context) => Consumer<TabProvider>(
    builder: (context, tabs, _) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(LucideIcons.package, color: colors.textPrimary, size: 26),
            onPressed: () => tabs.setTab(1),
            tooltip: 'Activity',
          ),
          GestureDetector(
            onTap: () async {
              // Open settings, then refresh the displayed active wallet name
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreenSettings()),
              );
              await context.read<WalletHomeProvider>().reloadActiveWalletName();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  walletName ?? 'My Wallet',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 18, color: colors.textPrimary),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 26),
            onPressed: () => tabs.setTab(3),
            tooltip: 'Settings',
          ),
        ],
      );
    },
  );
}

class _HeaderSection extends StatefulWidget {
  const _HeaderSection({
    required this.colors,
    required this.currencyFmt,
    required this.loadingBalances,
    required this.totalFiat,
    required this.lastBalancesAt,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
    required this.livePulse,
    required this.incomingStrip,
  });

  final AppColor colors;
  final NumberFormat currencyFmt;
  final bool loadingBalances;
  final double totalFiat;
  final DateTime? lastBalancesAt;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final AnimationController livePulse;
  final Widget incomingStrip;

  @override
  State<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<_HeaderSection> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Total Balance',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: widget.colors.textSecondary)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _hideBalance = !_hideBalance),
                        child: Icon(
                          _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: widget.colors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Always show the animated counter; no spinner.
                  _LiveCountingBalance(
                    hidden: _hideBalance,
                    targetValue: widget.totalFiat.isFinite ? widget.totalFiat : 0.0,
                    fmt: widget.currencyFmt,
                    baseColor: widget.colors.textPrimary,
                    loading: widget.loadingBalances,     // show pulsing dot when fetching
                    pulse: widget.livePulse,
                  ),

                  const SizedBox(height: 4),
                  _UpdatedAgoLabel(last: widget.lastBalancesAt, colors: widget.colors),
                ],
              ),

              // Right: swap button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  elevation: 3,
                ),
                onPressed: widget.onSwap,
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

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            actionButton(widget.colors, Icons.send, 'Send', gradient: true, onTap: widget.onSend),
            actionButton(widget.colors, Icons.call_received, 'Receive', gradient: true, onTap: widget.onReceive),
            actionButton(widget.colors, LucideIcons.wallet, 'Deposit', gradient: true,
                onTap: () => debugPrint('Deposit')),
            actionButton(widget.colors, Icons.arrow_upward, 'Withdraw', gradient: true,
                onTap: () => debugPrint('Withdraw')),
          ],
        ),
        const SizedBox(height: 20),
        widget.incomingStrip,
      ],
    );
  }
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
      if (!mounted) return;
      setState(() {});
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

class _TabKeepAliveState extends State<_TabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeyedSubtree(key: PageStorageKey(widget.storageKey), child: widget.child);
  }
}

/* ---------------------- Animated Counting Balance ---------------------- */

class _LiveCountingBalance extends StatefulWidget {
  const _LiveCountingBalance({
    required this.targetValue,
    required this.fmt,
    required this.baseColor,
    this.upColor = const Color(0xFF22C55E),   // green-500
    this.downColor = const Color(0xFFEF4444), // red-500
    this.hidden = false,
    this.loading = false,
    this.pulse,
  });

  final double targetValue;
  final NumberFormat fmt;
  final Color baseColor;
  final Color upColor;
  final Color downColor;
  final bool hidden;

  // New:
  final bool loading;
  final AnimationController? pulse;

  @override
  State<_LiveCountingBalance> createState() => _LiveCountingBalanceState();
}

class _LiveCountingBalanceState extends State<_LiveCountingBalance> {
  late double _display;   // animated number
  int _dir = 0;           // -1 ↓, 0 =, +1 ↑
  Timer? _ticker;

  static const _tick = Duration(seconds: 1);
  static const _minStep = 0.01; // currency smallest step

  @override
  void initState() {
    super.initState();
    _display = widget.targetValue.isFinite ? widget.targetValue : 0.0;
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant _LiveCountingBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Snap to neutral if target becomes invalid; ticker will hold value.
    if (!widget.targetValue.isFinite && _display.isFinite) {
      setState(() {
        _dir = 0;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!mounted) return;

      // Guard against NaN/Inf targets; hold last display until valid
      if (!widget.targetValue.isFinite) {
        setState(() => _dir = 0);
        return;
      }

      final target = widget.targetValue;
      final delta = target - _display;

      // Close enough → snap & neutral color
      if (delta.abs() <= _minStep) {
        setState(() {
          _display = target;
          _dir = 0;
        });
        return;
      }

      // Smooth, size-aware step: reach the target in ≈ 4–6 ticks, min one cent
      final dynamicStep = (delta.abs() / 4).clamp(_minStep, double.infinity);
      final step = delta.isNegative ? -dynamicStep : dynamicStep;

      setState(() {
        _display = double.parse((_display + step).toStringAsFixed(4));
        _dir = step > 0 ? 1 : -1;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _dir == 0
        ? widget.baseColor
        : (_dir > 0 ? widget.upColor : widget.downColor);

    return Row(
      children: [
        // Direction icon (up/down/none)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: _dir == 0
              ? const SizedBox(width: 0, key: ValueKey('eq'))
              : Icon(
            _dir > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            key: ValueKey(_dir > 0 ? 'up' : 'down'),
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 6),

        // The amount itself, animates color on direction
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          child: Text(widget.hidden ? '••••' : widget.fmt.format(_display)),
        ),

        // Subtle pulsing dot when we’re currently fetching (replaces spinner)
        if (widget.loading && widget.pulse != null) ...[
          const SizedBox(width: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.15).animate(widget.pulse!),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(widget.pulse!),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
