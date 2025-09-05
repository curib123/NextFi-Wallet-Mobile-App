import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

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
import 'package:next_fi/Services/tron_wallet_service.dart';

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
  // Services
  late final TronWalletService _tron = TronWalletService(TronClientConfig());

  // Wallet
  String? _tronAddress, _tronAddressHex41;
  Uint8List? _privateKey;

  // Balances
  double _trxBalance = 0, _usdtBalance = 0;
  bool _hideBalance = false, _loadingBalances = true;

  // Incoming hints
  final _incomingHints = <Map<String, dynamic>>[];
  final _dismissedHintIds = <String>{};

  // Throttling
  static const _minBalancesGap = Duration(minutes: 10);
  static const _minHintsGap = Duration(minutes: 10);

  // Timers / state
  Timer? _pollBalancesTimer, _pollHintsTimer;
  bool _balancesInFlight = false, _hintsInFlight = false;
  DateTime? _lastBalancesAt, _lastHintsAt;

  // Anim
  late final AnimationController _livePulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => mounted ? context.read<AssetProvider>().startRealtimeUpdates() : null);
    _loadWallet();
  }

  @override
  void dispose() {
    _pollBalancesTimer?.cancel();
    _pollHintsTimer?.cancel();
    _livePulse.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      _pollBalancesTimer?.cancel();
      _pollHintsTimer?.cancel();
    } else if (s == AppLifecycleState.resumed) {
      _startRealtime();
    }
  }

  // ---------- Helpers ----------
  static String _txIdOf(Map<String, dynamic> tx) => (tx['txID'] ?? tx['hash'] ?? '').toString();

  bool _isIncomingToMe(Map<String, dynamic> tx) {
    if (_tronAddress == null) return false;
    final c = (tx['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
    final to = (c['to_address'] ?? c['to'] ?? '').toString();
    if (to.isEmpty) return false;
    final b58 = to == _tronAddress;
    final hex41 = _tronAddressHex41 != null && to.toUpperCase() == _tronAddressHex41!.toUpperCase();
    return b58 || hex41;
  }

  bool _isSuccessTx(Map<String, dynamic> tx) {
    if (tx['confirmed'] == true) return true;
    final status = (tx['status'] ?? tx['receipt_status'] ?? '').toString().toUpperCase();
    if (status == 'SUCCESS') return true;
    final ret = tx['ret'];
    if (ret is List && ret.isNotEmpty) {
      final s = (ret.first['contractRet'] ?? '').toString().toUpperCase();
      if (s == 'SUCCESS') return true;
    }
    return false;
  }

  bool _shouldFetch(DateTime? last, Duration gap) => last == null || DateTime.now().difference(last) >= gap;

  void _dismissIncoming(String txId) => setState(() {
    _dismissedHintIds.add(txId);
    _incomingHints.removeWhere((t) => _txIdOf(t) == txId);
  });

  // ---------- Data fetch ----------
  Future<void> _loadWallet() async {
    final mnemonic = await SeedStorage.getSeed();
    if (!mounted || mnemonic == null || mnemonic.isEmpty) return;

    try {
      final pk = TronWalletService.derivePrivateKey(mnemonic);
      final pub = TronWalletService.publicKeyFromPrivateKey(pk);
      final address = TronWalletService.tronAddressFromPublicKey(pub);
      String? hex41;
      try {
        hex41 = TronWalletService.tronBase58ToHex(address);
      } catch (_) {}

      setState(() {
        _privateKey = pk;
        _tronAddress = address;
        _tronAddressHex41 = hex41;
      });

      await Future.wait([_fetchBalances(), _fetchIncomingHints()]);
      _startRealtime();
    } catch (_) {
      if (!mounted) return;
      showFloatingSnackBar(context,
          message: 'Failed to load wallet. Please check your mnemonic.', type: SnackBarType.error);
    }
  }

  Future<void> _fetchBalances() async {
    if (_tronAddress == null || _balancesInFlight || !_shouldFetch(_lastBalancesAt, _minBalancesGap)) return;
    _balancesInFlight = true;
    try {
      final trxSun = await _tron.getTrxBalance(_tronAddress!);
      final usdt = await _tron.getTrc20BalanceViaHolders(walletBase58: _tronAddress!);
      if (!mounted) return;
      setState(() {
        _trxBalance = trxSun / 1e6;
        _usdtBalance = usdt;
        _loadingBalances = false;
        _lastBalancesAt = DateTime.now();
      });
    } finally {
      _balancesInFlight = false;
    }
  }

  Future<void> _fetchIncomingHints() async {
    if (_tronAddress == null || _hintsInFlight || !_shouldFetch(_lastHintsAt, _minHintsGap)) return;
    _hintsInFlight = true;
    try {
      final history = await _tron.getTransactionHistory(_tronAddress!);
      final incoming = history.where((tx) => _isSuccessTx(tx) && _isIncomingToMe(tx)).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _incomingHints
          ..clear()
          ..addAll(incoming.where((tx) => !_dismissedHintIds.contains(_txIdOf(tx))));
        _lastHintsAt = DateTime.now();
      });
    } finally {
      _hintsInFlight = false;
    }
  }

  void _startRealtime() {
    _pollBalancesTimer?.cancel();
    _pollHintsTimer?.cancel();
    _pollBalancesTimer = Timer.periodic(_minBalancesGap, (_) => unawaited(_fetchBalances()));
    _pollHintsTimer = Timer.periodic(_minHintsGap, (_) => unawaited(_fetchIncomingHints()));
  }

  // ---------- UI ----------
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
              Column(
                children: [
                  // Top bar (fixed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _TopBar(colors: colors),
                  ),
                  // Header (fixed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _HeaderSection(
                      colors: colors,
                      currency: currency,
                      hideBalance: _hideBalance,
                      onToggleHide: () => setState(() => _hideBalance = !_hideBalance),
                      loadingBalances: _loadingBalances,
                      tronAddress: _tronAddress,
                      trxBalance: _trxBalance,
                      usdtBalance: _usdtBalance,
                      incomingStrip: (_tronAddress != null)
                          ? IncomingHintsStrip(
                        colors: colors,
                        tronAddress: _tronAddress!,
                        incomingHints: _incomingHints,
                        onAcknowledge: (tx) => _dismissIncoming(_txIdOf(tx)),
                      )
                          : const SizedBox.shrink(),
                      onSend: _onSend,
                      onReceive: _onReceive,
                      isUpdatingBalances: _balancesInFlight,
                      lastBalancesAt: _lastBalancesAt,
                      livePulse: _livePulse,
                    ),
                  ),
                  // Tabs (bar fixed)
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0), child: buildTabBar(colors)),
                  // Only tab content scrolls (per-tab state kept)
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TabKeepAlive(
                          storageKey: 'assetsTab',
                          child: AssetWidget(
                            colors: colors,
                            assets: assetProv.assets,
                            logos: assetProv.logos,
                            trxBalance: _trxBalance,
                            usdtBalance: _usdtBalance,
                            address: _tronAddress ?? '',
                            loading: assetProv.loading || currency.loading || _loadingBalances,
                            onItemTap: (token) {
                              if (_tronAddress == null) {
                                showFloatingSnackBar(context,
                                    message: "No address available", type: SnackBarType.error);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceiveScreen(
                                    address: _tronAddress!,
                                    trxBalance: _trxBalance,
                                    usdtBalance: _usdtBalance,
                                    initialToken: token,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        _TabKeepAlive(
                          storageKey: 'recipientsTab',
                          child: RecipientListWidget(colors: colors),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Floating overlay

              HomeFab(
                colors: colors,
                incomingHints: _incomingHints,
                tronAddress: _tronAddress,        // ← bang crash when wallet not yet loaded
                trxBalance: _trxBalance,
                usdtBalance: _usdtBalance,
              )

            ],
          ),
        ),
      ),
    );
  }

  // Actions
  void _onSend() {
    if (_tronAddress == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    showTokenSelector(
      context,
      _tronAddress!,
      _trxBalance,
      _usdtBalance,
      title: 'Send Token',
      screenBuilder: (address, token, balance) => SendScreen(address: address, token: token, balance: balance),
    );
  }

  void _onReceive() {
    if (_tronAddress == null) {
      showFloatingSnackBar(context, message: 'Wallet not loaded yet', type: SnackBarType.warning);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveScreen(
          address: _tronAddress!,
          trxBalance: _trxBalance,
          usdtBalance: _usdtBalance,
          initialToken: 'TRX',
        ),
      ),
    );
  }
}

// ---------- Small widgets ----------
class _TopBar extends StatelessWidget {
  const _TopBar({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        icon: Icon(LucideIcons.fileText, color: colors.textPrimary, size: 26),
        onPressed: () {},
        tooltip: 'Activity',
      ),
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tron Wallet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 18),
        ],
      ),
      IconButton(
        icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 26),
        onPressed: () {},
        tooltip: 'Settings',
      ),
    ],
  );
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.colors,
    required this.currency,
    required this.hideBalance,
    required this.onToggleHide,
    required this.loadingBalances,
    required this.tronAddress,
    required this.trxBalance,
    required this.usdtBalance,
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
  final String? tronAddress;
  final double trxBalance, usdtBalance;
  final Widget incomingStrip;
  final VoidCallback onSend, onReceive;
  final bool isUpdatingBalances;
  final DateTime? lastBalancesAt;
  final AnimationController livePulse;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final totalFiat = currency.trxToFiat(trxBalance) + currency.usdtToFiat(usdtBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.textSecondary)),
                      const SizedBox(width: 6),
                      GestureDetector(onTap: onToggleHide, child: Icon(hideBalance ? LucideIcons.eyeOff : LucideIcons.eye, color: colors.textSecondary, size: 18)),
                      const SizedBox(width: 8),
                      _LivePill(active: isUpdatingBalances, colors: colors, controller: livePulse),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (loadingBalances)
                    const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    _AnimatedFiat(value: hideBalance ? null : totalFiat, currencyFmt: currencyFmt, textColor: colors.textPrimary),
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
                onPressed: () {},
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
            actionButton(colors, Icons.send, 'Send', gradient: true, onTap: onSend),
            actionButton(colors, Icons.call_received, 'Receive', gradient: true, onTap: onReceive),
            actionButton(colors, LucideIcons.wallet, 'Deposit', gradient: true, onTap: () => debugPrint('Deposit')),
            actionButton(colors, Icons.arrow_upward, 'Withdraw', gradient: true, onTap: () => debugPrint('Withdraw')),
          ],
        ),
        const SizedBox(height: 20),
        incomingStrip,
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.active, required this.colors, required this.controller});
  final bool active;
  final AppColor colors;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final dot = ScaleTransition(
      scale: Tween<double>(begin: .8, end: 1).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle)),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1 : .35,
      child: Container(
        margin: const EdgeInsets.only(left: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: colors.success.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          dot,
          const SizedBox(width: 6),
          Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.success)),
        ]),
      ),
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
      ? Text('••••', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: textColor))
      : AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
    child: Text(currencyFmt.format(value), key: ValueKey(value), style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: textColor)),
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
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
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
    return Text(s <= 1 ? 'Updated just now' : 'Updated ${s}s ago',
        style: TextStyle(fontSize: 11, color: widget.colors.textSecondary));
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
