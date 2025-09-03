import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Components/token_chooser.dart';
import 'package:provider/provider.dart';

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
  const WalletHomeScreen({super.key, this.isTest = false});
  final bool isTest;

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
  bool _loadingHistory = true;

  // Data
  final List<Map<String, dynamic>> _transactionHistory = [];
  final List<Map<String, dynamic>> _incomingHints = [];
  final Set<String> _dismissedHintIds = {};
  final Set<String> _knownTxIds = {};

  // Realtime
  Timer? _pollBalancesTimer;
  Timer? _pollHistoryTimer;
  bool _balancesInFlight = false;
  bool _historyInFlight = false;
  DateTime? _lastBalancesAt;
  DateTime? _lastHistoryAt;

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
    // Microtask to ensure context is available.
    Future.microtask(() {
      if (!mounted) return;
      context.read<AssetProvider>().startRealtimeUpdates();
    });

    widget.isTest ? _loadTestMode() : _loadWallet();
  }

  @override
  void dispose() {
    _pollBalancesTimer?.cancel();
    _pollHistoryTimer?.cancel();
    _livePulse.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pause/resume polling when app goes background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pollBalancesTimer?.cancel();
      _pollHistoryTimer?.cancel();
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

  void _dismissIncoming(String txId) {
    setState(() {
      _dismissedHintIds.add(txId);
      _incomingHints.removeWhere((t) => _txIdOf(t) == txId);
    });
  }

  // ---------- Test Mode ----------

  void _loadTestMode() {
    final me = 'TPuTestModeD3moAddr3ssZZZ111';
    _tronAddress = me;
    try {
      _tronAddressHex41 = TronWalletService.tronBase58ToHex(me);
    } catch (_) {
      _tronAddressHex41 = null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final demo = <Map<String, dynamic>>[
      {
        'txID': '0xDEMO_USDT_01',
        'token': 'USDT',
        'decimals': 6,
        'timestamp': now - 60 * 1000,
        'contract_type': 'TriggerSmartContract',
        'confirmed': true,
        'contract': {
          'from_address': 'TUxSender1111111111111111111',
          'to_address': me,
          'symbol': 'USDT',
          'amount': 2_534_999,
          'decimals': 6,
        },
      },
      {
        'txID': '0xDEMO_TRX_02',
        'token': 'TRX',
        'decimals': 6,
        'timestamp': now - 5 * 60 * 1000,
        'contract_type': 'TransferContract',
        'confirmed': true,
        'contract': {
          'from_address': 'TVySender2222222222222222222',
          'to_address': me,
          'symbol': 'TRX',
          'amount': 1_250_000,
          'decimals': 6,
        },
      },
    ];

    final incoming = demo.where((tx) {
      final success = _isSuccessTx(tx);
      final incomingToMe = _isIncomingToMe(tx);
      final notDismissed = !_dismissedHintIds.contains(_txIdOf(tx));
      return success && incomingToMe && notDismissed;
    }).toList();

    setState(() {
      _trxBalance = 123.456789;
      _usdtBalance = 789.012345;
      _loadingBalances = false;

      _transactionHistory
        ..clear()
        ..addAll(demo);
      _incomingHints
        ..clear()
        ..addAll(incoming);

      _knownTxIds.addAll(demo.map(_txIdOf));
      _loadingHistory = false;
      _lastBalancesAt = DateTime.now();
      _lastHistoryAt = DateTime.now();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Test mode: showing demo balances & transactions',
        type: SnackBarType.warning,
      );
    });

    _startRealtime();

    // Simulate a new incoming TX in test mode after 6s
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted || _tronAddress == null) return;
      final tx = {
        'txID': '0xDEMO_USDT_NEW',
        'token': 'USDT',
        'decimals': 6,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'contract_type': 'TriggerSmartContract',
        'confirmed': true,
        'contract': {
          'from_address': 'TDemoSenderNEW',
          'to_address': _tronAddress!,
          'symbol': 'USDT',
          'amount': 5_000_000,
          'decimals': 6,
        },
      };
      if (!mounted) return;
      setState(() {
        _transactionHistory.insert(0, tx);
        _knownTxIds.add(_txIdOf(tx));
        _incomingHints.insert(0, tx);
      });
      if (!mounted) return;
      showFloatingSnackBar(
        context,
        message: 'Incoming 5 USDT',
        type: SnackBarType.success,
      );
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

      await Future.wait([_fetchBalances(), _fetchTransactionHistory()]);
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
    if (_tronAddress == null || _balancesInFlight) return;
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
        _lastBalancesAt = DateTime.now();
      });

      final changedTrx = (prevTrx - _trxBalance).abs() >= 0.000001;
      final changedUsdt = (prevUsdt - _usdtBalance).abs() >= 0.000001;
      if (changedTrx || changedUsdt) {
        // reserved for subtle UI animations/haptics
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
    } finally {
      _balancesInFlight = false;
    }
  }

  Future<void> _fetchTransactionHistory() async {
    if (_tronAddress == null || _historyInFlight) return;
    _historyInFlight = true;

    try {
      final history = await _tron.getTransactionHistory(_tronAddress!);
      if (!mounted) return;

      final incomingAll = history.where((tx) {
        final success = _isSuccessTx(tx);
        final incomingToMe = _isIncomingToMe(tx);
        return success && incomingToMe;
      }).toList();

      final newOnes =
      incomingAll.where((tx) => !_knownTxIds.contains(_txIdOf(tx))).toList(growable: false);

      setState(() {
        _transactionHistory
          ..clear()
          ..addAll(history);

        final undismissed = incomingAll
            .where((tx) => !_dismissedHintIds.contains(_txIdOf(tx)))
            .toList(growable: false);
        _incomingHints
          ..clear()
          ..addAll(undismissed);

        _knownTxIds.addAll(history.map(_txIdOf));
        _loadingHistory = false;
        _lastHistoryAt = DateTime.now();
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
      debugPrint('Error fetching Tron transaction history: $e');
    } finally {
      _historyInFlight = false;
    }
  }

  // start/stop periodic polling
  void _startRealtime() {
    _pollBalancesTimer?.cancel();
    _pollHistoryTimer?.cancel();

    unawaited(_fetchBalances());
    unawaited(_fetchTransactionHistory());

    _pollBalancesTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) unawaited(_fetchBalances());
    });
    _pollHistoryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) unawaited(_fetchTransactionHistory());
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final colors = AppColor.of(context);
    final currency = context.watch<CurrencyProvider>(); // centralized conversion
    final assetProv = context.watch<AssetProvider>();   // percent changes + logos

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
                  title: _TopBar(isTest: widget.isTest, colors: colors),
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
  const _TopBar({required this.isTest, required this.colors});
  final bool isTest;
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
          children: [
            const Text('Tron Wallet',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(width: 6),
            if (isTest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.warning.withOpacity(.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.warning.withOpacity(.25)),
                ),
                child: Text(
                  'TEST',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: colors.warning),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown, size: 18),
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
    final currencyFmt =
    NumberFormat.simpleCurrency(name: currency.fiat.toUpperCase());
    final totalFiat =
        currency.trxToFiat(trxBalance) + currency.usdtToFiat(usdtBalance);

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
