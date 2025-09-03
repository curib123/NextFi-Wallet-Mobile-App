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
import 'WalletHomeScreenWidgets/floating_circle_button.dart';
import 'WalletHomeScreenWidgets/incoming_payment_hints.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Services
  late final TronWalletService _tron =
  TronWalletService(TronClientConfig(baseUrl: 'https://api.trongrid.io'));

  // Wallet
  String? _tronAddress;
  String? _tronAddressHex41;
  Uint8List? _privateKey;

  // Balances
  double _trxBalance = 0.0;
  double _usdtBalance = 0.0;
  bool _hideBalance = false;

  // Loading flags
  bool _loadingBalances = true;

  // Incoming hints only (no history kept)
  final List<Map<String, dynamic>> _incomingHints = [];
  final Set<String> _dismissedHintIds = {};
  final Set<String> _knownTxIds = {};

// ---- Throttling config (prod-safe) ----
  static const Duration _minBalancesGap = Duration(minutes: 10);
  static const Duration _minHintsGap    = Duration(minutes: 10);


  // Realtime / last-run trackers
  Timer? _pollBalancesTimer;
  Timer? _pollHintsTimer;
  bool _balancesInFlight = false;
  bool _hintsInFlight = false;
  DateTime? _lastBalancesAt; // updated on success
  DateTime? _lastHintsAt; // updated on success

  // Anim helpers
  late final AnimationController _livePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start asset-provider realtime (logos + % changes).
    Future.microtask(() {
      if (!mounted) return;
      context.read<AssetProvider>().startRealtimeUpdates();
    });

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

  // Pause/resume polling when app goes background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pollBalancesTimer?.cancel();
      _pollHintsTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startRealtime();
    }
  }

  // ---------- Helpers ----------

  static String _txIdOf(Map<String, dynamic> tx) =>
      (tx['txID'] ?? tx['hash'] ?? '').toString();

  bool _isIncomingToMe(Map<String, dynamic> tx) {
    if (_tronAddress == null) return false;
    final c = (tx['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
    final to = (c['to_address'] ?? c['to'] ?? '').toString();
    if (to.isEmpty) return false;
    final matchBase58 = to == _tronAddress;
    final matchHex =
        _tronAddressHex41 != null && to.toUpperCase() == _tronAddressHex41!.toUpperCase();
    return matchBase58 || matchHex;
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

  bool _shouldFetch(DateTime? last, Duration gap) {
    if (last == null) return true;
    return DateTime.now().difference(last) >= gap;
  }

  void _dismissIncoming(String txId) {
    setState(() {
      _dismissedHintIds.add(txId);
      _incomingHints.removeWhere((t) => _txIdOf(t) == txId);
    });
  }

  // ---------- Wallet / Data ----------

  Future<void> _loadWallet() async {
    final storedMnemonic = await SeedStorage.getSeed();
    if (!mounted) return;
    if (storedMnemonic == null || storedMnemonic.isEmpty) return;

    try {
      final privKey = TronWalletService.derivePrivateKey(storedMnemonic);
      final pubKey = TronWalletService.publicKeyFromPrivateKey(privKey);
      final address = TronWalletService.tronAddressFromPublicKey(pubKey);

      String? hex41;
      try {
        hex41 = TronWalletService.tronBase58ToHex(address);
      } catch (_) {
        hex41 = null;
      }

      setState(() {
        _privateKey = privKey;
        _tronAddress = address;
        _tronAddressHex41 = hex41;
      });

      // initial fetches
      await Future.wait([
        _fetchBalances(),
        _fetchIncomingHints(),
      ]);

      _startRealtime();
    } catch (e) {
      debugPrint('Failed to load Tron wallet: $e');
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Failed to load wallet. Please check your mnemonic.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _fetchBalances() async {
    if (_tronAddress == null) return;
    if (_balancesInFlight) return;
    if (!_shouldFetch(_lastBalancesAt, _minBalancesGap)) return;

    _balancesInFlight = true;

    final prevTrx = _trxBalance;
    final prevUsdt = _usdtBalance;

    try {
      final trxSun = await _tron.getTrxBalance(_tronAddress!);
      final usdt = await _tron.getTrc20BalanceViaHolders(walletBase58: _tronAddress!);
      if (!mounted) return;
      setState(() {
        _trxBalance = trxSun / 1e6;
        _usdtBalance = usdt;
        _loadingBalances = false;
        _lastBalancesAt = DateTime.now(); // success time
      });

      final changedTrx = (prevTrx - _trxBalance).abs() >= 0.000001;
      final changedUsdt = (prevUsdt - _usdtBalance).abs() >= 0.000001;
      if (changedTrx || changedUsdt) {
        // optional: gentle animation/haptic
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
      // keep _lastBalancesAt unchanged on error
    } finally {
      _balancesInFlight = false;
    }
  }

  /// Fetch **incoming** successful transactions and surface them as hints only.
  /// No transaction history is stored; throttled to avoid redundant calls.
  Future<void> _fetchIncomingHints() async {
    if (_tronAddress == null) return;
    if (_hintsInFlight) return;
    if (!_shouldFetch(_lastHintsAt, _minHintsGap)) return;

    _hintsInFlight = true;
    try {
      final history = await _tron.getTransactionHistory(_tronAddress!);

      final incomingAll = history.where((tx) {
        final success = _isSuccessTx(tx);
        final incomingToMe = _isIncomingToMe(tx);
        return success && incomingToMe;
      }).toList(growable: false);

      final newOnes = incomingAll
          .where((tx) => !_knownTxIds.contains(_txIdOf(tx)))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        final undismissed = incomingAll
            .where((tx) => !_dismissedHintIds.contains(_txIdOf(tx)))
            .toList(growable: false);

        _incomingHints
          ..clear()
          ..addAll(undismissed);

        _knownTxIds.addAll(incomingAll.map(_txIdOf));
        _lastHintsAt = DateTime.now(); // success time
      });

      for (final tx in newOnes) {
        final c = (tx['contract'] as Map?)?.cast<String, dynamic>() ?? const {};
        final sym = (c['symbol'] ?? '').toString();
        final dec = (c['decimals'] ?? 6) as int;
        final amt = (c['amount'] ?? 0) as int;
        final value = amt / pow10(dec);
        if (!mounted) break;
        showFloatingSnackBar(
          context,
          message: 'Incoming ${value.toStringAsFixed(4)} $sym',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error fetching incoming hints: $e');
      // keep _lastHintsAt unchanged on error
    } finally {
      _hintsInFlight = false;
    }
  }

  // start/stop periodic polling
  void _startRealtime() {
    _pollBalancesTimer?.cancel();
    _pollHintsTimer?.cancel();

    // No immediate fetch here; initial fetch already done in _loadWallet()

    // Poll at cadence >= min gap. Each fetch also self-gates.
    _pollBalancesTimer = Timer.periodic(_minBalancesGap, (_) {
      if (mounted) unawaited(_fetchBalances());
    });
    _pollHintsTimer = Timer.periodic(_minHintsGap, (_) {
      if (mounted) unawaited(_fetchIncomingHints());
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = context.watch<CurrencyProvider>(); // centralized conversion
    final assetProv = context.watch<AssetProvider>(); // percent changes + logos

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                SliverAppBar(
                  backgroundColor: colors.surface,
                  elevation: innerScrolled ? 2 : 0,
                  pinned: true,
                  title: _TopBar(colors: colors),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: _HeaderSection(
                      colors: colors,
                      currency: currency,
                      hideBalance: _hideBalance,
                      onToggleHide: () => setState(() => _hideBalance = !_hideBalance),
                      loadingBalances: _loadingBalances,
                      tronAddress: _tronAddress,
                      trxBalance: _trxBalance,
                      usdtBalance: _usdtBalance,
                      incomingHints: _incomingHints,
                      onAcknowledge: (tx) => _dismissIncoming(_txIdOf(tx)),
                      onSend: _onSend,
                      onReceive: _onReceive,
                      isUpdatingBalances: _balancesInFlight,
                      lastBalancesAt: _lastBalancesAt,
                      livePulse: _livePulse,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: buildTabBar(colors),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  AssetWidget(
                    colors: colors,
                    assets: assetProv.assets,
                    logos: assetProv.logos,
                    trxBalance: _trxBalance,
                    usdtBalance: _usdtBalance,
                    loading: assetProv.loading || currency.loading || _loadingBalances,
                  ),
                  RecipientListWidget(colors: colors),
                ],
              ),
            ),
            _buildFloatingButtons(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons(AppColor colors) {
    return Positioned(
      bottom: 10,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          floatingCircleButton(
            onTap: () {
              // TODO: scanner / quick action
            },
            icon: LucideIcons.scanLine,
            color: colors.primary,
          ),
        ],
      ),
    );
  }

  // Actions
  void _onSend() {
    if (_tronAddress == null) {
      showFloatingSnackBar(
        context,
        message: 'Wallet not loaded yet',
        type: SnackBarType.warning,
      );
      return;
    }
    showTokenSelector(
      context,
      _tronAddress!,
      _trxBalance,
      _usdtBalance,
      title: 'Send Token',
      screenBuilder: (address, token, balance) => SendScreen(
        address: address,
        token: token,
        balance: balance,
      ),
    );
  }

  void _onReceive() {
    if (_tronAddress == null) {
      showFloatingSnackBar(
        context,
        message: 'Wallet not loaded yet',
        type: SnackBarType.warning,
      );
      return;
    }
    showTokenSelector(
      context,
      _tronAddress!,
      _trxBalance,
      _usdtBalance,
      title: 'Receive Token',
      screenBuilder: (address, token, balance) => ReceiveScreen(
        address: address,
        token: token,
        balance: balance,
      ),
    );
  }
}

// ---------- Small, focused widgets ----------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.colors});
  final AppColor colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(LucideIcons.fileText, color: colors.textPrimary, size: 26),
          onPressed: () {},
          tooltip: 'Activity',
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Tron Wallet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 18),
          ],),
        IconButton(
          icon: Icon(LucideIcons.settings, color: colors.textPrimary, size: 26),
          onPressed: () {},
          tooltip: 'Settings',
        ),
      ],
    );
  }
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
    required this.incomingHints,
    required this.onAcknowledge,
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
  final double trxBalance;
  final double usdtBalance;
  final List<Map<String, dynamic>> incomingHints;
  final void Function(Map<String, dynamic> tx) onAcknowledge;
  final VoidCallback onSend;
  final VoidCallback onReceive;

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
        // Balance card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 6)),
            ],
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
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onToggleHide,
                        child: Icon(
                          hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: colors.textSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _LivePill(active: isUpdatingBalances, colors: colors, controller: livePulse),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (loadingBalances)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  elevation: 3,
                ),
                onPressed: () {},
                child: Row(
                  children: const [
                    Icon(LucideIcons.shuffle, size: 22, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Swap',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Four action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            actionButton(colors, Icons.send, 'Send', gradient: true, onTap: onSend),
            actionButton(colors, Icons.call_received, 'Receive', gradient: true, onTap: onReceive),
            actionButton(colors, LucideIcons.wallet, 'Deposit', gradient: true,
                onTap: () => debugPrint('Deposit')),
            actionButton(colors, Icons.arrow_upward, 'Withdraw', gradient: true,
                onTap: () => debugPrint('Withdraw')),
          ],
        ),

        const SizedBox(height: 20),

        // Incoming payment hints directly below action buttons
        if (tronAddress != null && incomingHints.isNotEmpty) ...[
          for (final tx in incomingHints)
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: incomingPaymentHint(
                tx,
                tronAddress!,
                onAcknowledge: () => onAcknowledge(tx),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------- tiny UI helpers for "live" feel ----------

class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.active,
    required this.colors,
    required this.controller,
  });
  final bool active;
  final AppColor colors;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final dot = ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0)
          .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1 : .35,
      child: Container(
        margin: const EdgeInsets.only(left: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.success.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedFiat extends StatelessWidget {
  const _AnimatedFiat({
    required this.value,
    required this.currencyFmt,
    required this.textColor,
  });

  final double? value; // null -> hidden/obscured
  final NumberFormat currencyFmt;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text(
        '••••',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: textColor),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Text(
        currencyFmt.format(value),
        key: ValueKey(value),
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: textColor),
      ),
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
    final secs = DateTime.now().difference(widget.last!).inSeconds;
    final text = secs <= 1 ? 'Updated just now' : 'Updated ${secs}s ago';
    return Text(text, style: TextStyle(fontSize: 11, color: widget.colors.textSecondary));
  }
}

// ---------- math util ----------

double pow10(int n) {
  double x = 1;
  for (int i = 0; i < n; i++) x *= 10;
  return x;
}

// ---------- unawaited helper ----------
void unawaited(Future<void> f) {}
